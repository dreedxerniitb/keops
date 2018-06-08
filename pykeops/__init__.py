import sys
import os.path

###########################################################
#              Compilation options
###########################################################

script_folder = os.path.dirname(os.path.abspath(__file__)) + os.path.sep + '..' + os.path.sep + "pykeops"
build_folder  = os.path.dirname(os.path.abspath(__file__)) + os.path.sep + '..' + os.path.sep + "build" + os.path.sep
verbose = False # display output of compilations
build_type = "Release" # 'Release' or 'Debug'

default_cuda_type = 'float'
dll_prefix = "lib"
dll_ext = ".so"

sys.path.append(build_folder)

###########################################################
# get some infos about the system
###########################################################

from .common.get_options import gpu_available, torch_found
