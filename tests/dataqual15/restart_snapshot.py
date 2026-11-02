"""Read one published generation without blocking native Windows replacement."""
import os
from pathlib import Path

def read_snapshot(path):
    path=Path(path)
    if os.name!='nt':return path.read_bytes()
    import ctypes,msvcrt
    kernel=ctypes.WinDLL('kernel32',use_last_error=True)
    kernel.CreateFileW.argtypes=[ctypes.c_wchar_p,ctypes.c_uint32,ctypes.c_uint32,ctypes.c_void_p,
                                ctypes.c_uint32,ctypes.c_uint32,ctypes.c_void_p]
    kernel.CreateFileW.restype=ctypes.c_void_p
    handle=kernel.CreateFileW(str(path),0x80000000,1|2|4,None,3,0,None)
    if handle==ctypes.c_void_p(-1).value:
        raise ctypes.WinError(ctypes.get_last_error())
    try:fd=msvcrt.open_osfhandle(handle,os.O_RDONLY|os.O_BINARY)
    except Exception:
        kernel.CloseHandle.argtypes=[ctypes.c_void_p];kernel.CloseHandle(handle);raise
    with os.fdopen(fd,'rb')as stream:return stream.read()
