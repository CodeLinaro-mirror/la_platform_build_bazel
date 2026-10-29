#include "rules_cc/cc/runfiles/runfiles.h"

#include <cstdlib>
#include <cstring>
#include <memory>
#include <string>
#include <unistd.h>

using rules_cc::cc::runfiles::Runfiles;

static std::string resolve_execroot_path(const char *argv0_cstr, const char *rel_execpath) {
    if (access(rel_execpath, F_OK) == 0) {
        char *real = realpath(rel_execpath, nullptr);
        if (real != nullptr) {
            std::string res(real);
            free(real);
            return res;
        }
    }
    if (argv0_cstr != nullptr) {
        std::string s(argv0_cstr);
        size_t pos = s.find("/bazel-out/");
        if (pos != std::string::npos) {
            std::string candidate = s.substr(0, pos + 1) + rel_execpath;
            if (access(candidate.c_str(), F_OK) == 0) {
                char *real = realpath(candidate.c_str(), nullptr);
                if (real != nullptr) {
                    std::string res(real);
                    free(real);
                    return res;
                }
                return candidate;
            }
        }
    }
    return "";
}

extern "C" void flex_bazel_runfiles_init(const char *argv0_cstr) {
    if (getenv("M4") != nullptr) {
        return;
    }
    std::string error;
    std::unique_ptr<Runfiles> runfiles(
        Runfiles::Create(argv0_cstr ? argv0_cstr : "", BAZEL_CURRENT_REPOSITORY, &error));
    if (runfiles != nullptr) {
        std::string result = runfiles->Rlocation(M4_RLOCATION);
        if (!result.empty() && access(result.c_str(), X_OK) == 0) {
            setenv("M4", result.c_str(), 0);
            return;
        }
    }
    std::string fallback = resolve_execroot_path(argv0_cstr, M4_EXECPATH);
    if (!fallback.empty()) {
        setenv("M4", fallback.c_str(), 0);
    }
}
