from __future__ import annotations

import json
import os
import subprocess
import sys
from pathlib import Path
from typing import Any


class RibasimWorker:
    def __init__(
        self,
        *,
        model_path: Path,
        lib_path: Path,
        ribasim_root: Path,
        log_path: Path,
    ) -> None:
        self.model_path=Path(model_path).resolve()
        self.lib_path=Path(lib_path).resolve()
        self.ribasim_root=Path(ribasim_root).resolve()
        self.log_path=Path(log_path).resolve()
        read_fd,write_fd=os.pipe()
        env=os.environ.copy()
        env["RM13_WORKER_RESPONSE_FD"]=str(write_fd)
        env["RM13_RIBASIM_ROOT"]=str(self.ribasim_root)
        env["RM13_WORKER_MODEL"]=str(self.model_path)
        env["RM13_LIBRIBASIM"]=str(self.lib_path)
        self._log=self.log_path.open("w",encoding="utf-8")
        worker=Path(__file__).with_name("rm13_ribasim_worker.py")
        self._process=subprocess.Popen(
            [sys.executable,str(worker)],
            stdin=subprocess.PIPE,
            stdout=self._log,
            stderr=subprocess.STDOUT,
            text=True,
            bufsize=1,
            env=env,
            pass_fds=(write_fd,),
        )
        os.close(write_fd)
        self._response=os.fdopen(read_fd,"r",encoding="utf-8",buffering=1)
        ready=self._read_response()
        if ready.get("op")!="ready":
            raise RuntimeError(f"RM13 worker did not return ready: {ready}")
        self.ready=ready

    def _tail_log(self) -> str:
        try:
            self._log.flush()
            text=self.log_path.read_text(encoding="utf-8",errors="replace")
            return text[-12000:]
        except Exception:
            return ""

    def _read_response(self) -> dict[str,Any]:
        line=self._response.readline()
        if not line:
            rc=self._process.poll()
            raise RuntimeError(
                f"RM13 Ribasim worker ended without response rc={rc}; log tail:\n{self._tail_log()}"
            )
        payload=json.loads(line)
        if not payload.get("ok",False):
            raise RuntimeError(
                f"RM13 Ribasim worker error: {payload}; log tail:\n{self._tail_log()}"
            )
        return payload

    def command(self,op: str,**kwargs: Any) -> dict[str,Any]:
        if self._process.poll() is not None:
            raise RuntimeError(
                f"RM13 Ribasim worker already exited rc={self._process.returncode}; "
                f"log tail:\n{self._tail_log()}"
            )
        assert self._process.stdin is not None
        self._process.stdin.write(json.dumps({"op":op,**kwargs},separators=(",",":"))+"\n")
        self._process.stdin.flush()
        return self._read_response()

    def snapshot(self) -> dict[str,float]:
        return self.command("snapshot")["snapshot"]

    def update_until(self,time_s: float) -> dict[str,float]:
        return self.command("update_until",time_s=float(time_s))["snapshot"]

    def finalize(self) -> None:
        self.command("finalize")

    def stop(self) -> None:
        if self._process.poll() is None:
            try:
                self.command("stop")
            except Exception:
                self._process.terminate()
        try:
            self._process.wait(timeout=30)
        except subprocess.TimeoutExpired:
            self._process.kill()
            self._process.wait(timeout=10)
        self._response.close()
        self._log.close()

    def __enter__(self) -> "RibasimWorker":
        return self

    def __exit__(self,exc_type,exc,tb) -> None:
        self.stop()
