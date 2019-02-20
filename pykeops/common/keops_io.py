import importlib

from pykeops import build_type, build_folder
from pykeops.common.utils import create_name, filelock
from pykeops.common.compile_routines import compile_generic_routine


def load_keops(formula, aliases, cuda_type, lang, optional_flags=[]):
    """
    Load the keops shared library that corresponds to the given formula, aliases, cuda_type and lang.
    If the shared library cannot be loaded, it will be compiled.
    Note: This function is thread/process safe by using a file lock.

    :return: The Python function that corresponds to the loaded Keops kernel.
    """

    @filelock(build_folder, lock_file_name='pykeops_build.lock')
    def _safe_compile(formula, aliases, dll_name, cuda_type, lang, optional_flags):
        compile_generic_routine(formula, aliases, dll_name, cuda_type, lang, optional_flags)

    @filelock(build_folder, lock_file_name='pykeops_build.lock')
    def _safe_compile_and_load(formula, aliases, dll_name, cuda_type, lang, optional_flags):
        """
        Safely compile and load shared library.
        """
        # check if previously compiled by other thread/process
        try:
            # already compiled, just load
            ret = importlib.import_module(dll_name)
            print(dll_name + " already compiled !")
            return ret
        except ImportError:
            # not yet compiled, compile and load
            print(dll_name + " not found")
            compile_generic_routine(formula, aliases, dll_name, cuda_type, lang, optional_flags)
            return importlib.import_module(dll_name)

    # create the name from formula, aliases and cuda_type.
    dll_name = create_name(formula, aliases, cuda_type, lang)

    if build_type == 'Debug':
        # force compile when in Debug
        _safe_compile(formula, aliases, dll_name, cuda_type, lang, optional_flags)

    try:
        # high frequency path
        return importlib.import_module(dll_name)
    except ImportError:
        # could not import (ie not compiled), safely compile/import
        return _safe_compile_and_load(formula, aliases, dll_name, cuda_type, lang, optional_flags)
