#! /usr/bin/env python3

"""A credential helper for Bazel, intended for CI builds on Android Build."""

import datetime
import json
import logging
import os
import re
import signal
import sys
import time
import types
from typing import Dict, Optional, Sequence
import urllib.error
import urllib.request

_GOOGLE_URI_RE = re.compile(
    r"^https://(?:[^/.]+\.)*(?:pkg\.dev|googleapis\.com)(?:/.*)?$"
)
_RFC3339_FORMAT = "%Y-%m-%dT%H:%M:%SZ"
_TIMEOUT = 60


class CredentialError(Exception):
  pass


def main(argv: Sequence[str]) -> int:
  start_time = time.perf_counter()
  _setup_logging()
  for signame in ("SIGTERM", "SIGINT", "SIGHUP"):
    if hasattr(signal, signame):
      signal.signal(getattr(signal, signame), _handle_signal)
  logging.info("Starting ci_credhelper with args: %s", argv)
  try:
    _run(argv)
    return 0
  except Exception:  # pylint: disable=broad-exception-caught
    logging.exception("ci_credhelper failed")
    return 1
  finally:
    total_elapsed = time.perf_counter() - start_time
    logging.info(
        "Total ci_credhelper execution time: %.3f seconds", total_elapsed
    )


def _setup_logging() -> None:
  """Configures logging to stderr and $DIST_DIR/logs/."""
  dist_dir = os.getenv("DIST_DIR")
  if not dist_dir:
    raise FileNotFoundError("DIST_DIR is not set")

  log_dir = os.path.join(dist_dir, "logs")
  os.makedirs(log_dir, exist_ok=True)
  timestamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
  log_file = os.path.join(
      log_dir, f"ci_credhelper.{timestamp}.{os.getpid()}.log"
  )

  logging.basicConfig(
      level=logging.INFO,
      format=(
          "%(levelname).1s%(asctime)s %(process)d %(filename)s:%(lineno)d]"
          " %(message)s"
      ),
      datefmt="%m%d %H:%M:%S",
      handlers=[
          logging.FileHandler(log_file),
          logging.StreamHandler(sys.stderr),  # direct console logs to stderr
      ],
  )


def _handle_signal(signum: int, frame: Optional[types.FrameType]) -> None:
  """Handles termination signals by logging a warning and exiting."""
  del frame  # unused
  try:
    signame = signal.Signals(signum).name
  except ValueError:
    signame = f"UNKNOWN ({signum})"
  logging.warning("Received signal %s; terminating", signame)
  sys.exit(128 + signum)


def _run(argv: Sequence[str]) -> None:
  """Parses the input request from stdin and emits credential tokens."""
  if not argv:
    raise ValueError("Missing command")
  if argv[0] != "get":
    raise ValueError(f"Unknown command: {argv[0]}")

  logging.info("Reading request payload from stdin...")
  stdin_start = time.perf_counter()
  request = sys.stdin.read()
  stdin_elapsed = time.perf_counter() - stdin_start
  logging.info(
      "Read %d bytes from stdin in %.3f seconds", len(request), stdin_elapsed
  )

  try:
    request_json = json.loads(request)
  except json.JSONDecodeError as e:
    raise ValueError(f"Invalid JSON: {request}") from e
  if "uri" not in request_json:
    raise ValueError(f"Missing 'uri' field: {request_json}")
  uri = request_json["uri"]
  logging.info("Processing request for URI: %s", uri)

  if not os.getenv("BUILD_NUMBER"):
    raise NotImplementedError(f"Not a CI build: {uri}")

  if _GOOGLE_URI_RE.match(uri):
    _respond_google()
    return

  raise NotImplementedError(f"Unsupported URI: {uri}")


def _respond_google() -> None:
  """Responds to a request by fetching a SA token from the metadata server."""
  metadata_server = "metadata.google.internal"
  if os.getenv("GCE_METADATA_HOST"):
    metadata_server = os.getenv("GCE_METADATA_HOST")
  try:
    response_str = _request(
        "GET",
        {"Metadata-Flavor": "Google"},
        f"http://{metadata_server}/computeMetadata/v1/instance/service-accounts/default/token?alt=json",
    )
  except (urllib.error.HTTPError, urllib.error.URLError) as e:
    raise CredentialError(f"Failed to read token from {metadata_server}") from e

  try:
    response = json.loads(response_str)
    token, expires_in = response["access_token"], response["expires_in"]
  except (json.JSONDecodeError, KeyError) as e:
    raise CredentialError(
        f"Failed to parse response from {metadata_server}: {response_str}"
    ) from e

  expires = datetime.datetime.now(datetime.timezone.utc) + datetime.timedelta(
      seconds=expires_in
  )
  logging.info(
      "Retrieved service account token (expires in %d seconds at %s)",
      expires_in,
      expires.strftime(_RFC3339_FORMAT),
  )
  _print_response(token, expires)


def _print_response(
    token: Optional[str], expires: Optional[datetime.datetime]
) -> None:
  """Formats and writes the credential helper JSON response to stdout."""
  response = {}
  if token:
    response["headers"] = {
        "Authorization": [f"Bearer {token}"],
    }
  if expires:
    response["expires"] = expires.astimezone(datetime.timezone.utc).strftime(
        _RFC3339_FORMAT
    )
  logging.info("Writing JSON credential helper response to stdout")
  print(json.dumps(response), flush=True)


def _request(
    method: Optional[str],
    headers: Dict[str, str],
    url: str,
) -> str:
  """Makes an HTTP request and returns the response body."""
  logging.info(
      "Sending %s request to %s (timeout=%ds)...", method, url, _TIMEOUT
  )
  req = urllib.request.Request(
      url,
      headers=headers,
      method=method,
  )
  req_start = time.perf_counter()
  with urllib.request.urlopen(req, timeout=_TIMEOUT) as resp:
    body = resp.read().decode("utf-8")
    req_elapsed = time.perf_counter() - req_start
    logging.info(
        "Read %d bytes from %s request to %s (status %d) in %.3f seconds",
        len(body),
        method,
        url,
        resp.status,
        req_elapsed,
    )
    return body


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
