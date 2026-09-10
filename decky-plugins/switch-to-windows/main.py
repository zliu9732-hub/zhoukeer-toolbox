"""Decky Loader entry point for Switch to Windows."""

import os
import sys

PLUGIN_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(PLUGIN_DIR, "backend", "src"))

import switch_to_windows as _backend  # noqa: E402

Plugin = _backend.Plugin
# Keep these module attributes available to the existing unit tests and local
# development helpers; they refer to the same module objects used by the backend.
os = _backend.os
shutil = _backend.shutil
