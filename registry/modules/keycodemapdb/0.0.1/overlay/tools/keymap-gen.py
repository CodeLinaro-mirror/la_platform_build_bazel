#!/usr/bin/env python3
import os
import runpy

if __name__ == "__main__":
    runpy.run_path(
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "keymap-gen"),
        run_name="__main__",
    )
