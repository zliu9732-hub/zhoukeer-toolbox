#!/usr/bin/env python3
"""Steamcommunity 302 15.0.9 local control adapter; no external requests.

Protocol verified against the vendor's 15.0.9 Linux artifact, including its
service installer, frontend client and Go JSON types. Never disable TLS checks
or read the service's private CA key. The bearer token stays in process memory.
"""
import hashlib
import copy
import base64
import http.client
import json
import os
from pathlib import Path
import re
import socket
import stat
import sys
import time
import uuid

VERSION = "15.0.9"
IMAGE_SHA256 = "7884bbf43abe9b6202de37c133b3edfd8ff768c6c533e8d822d8aabf3a6f3fdd"
RULES = "Steam_store,Steam_store_unlock,Steam_community,Steam_API,Steam_API_unlock,Steam_community_unlock,steamchat,steamchat_unlock,Steam_cloud_google,steam_update,Steam_broadcast_redir,Steam_broadcast_redir_unlock,imgfix,imgfix_fastly,github".split(",")
RESOURCES = {
    "S302_rules.ini": "0fc810449f21bc7647bd8d38edf3af3cc9a9882ff66f8eb02eb23aaa1f7b5fe1",
    "iframe_api": "ff805e27f6c9f3df8fc312d1cb24ad96db942d07e9425977a16a79ba9418f9fa",
    "iframe_api.js": "98e202cf66f153ca701fb9beed0b86c60f806a90afe624f75cb631103ff2beb7",
    "steamcommunity_302.caddy": "34d3d47f819786982faa85abc686832cc72cbcd88de2b15610840c36b341b6dd",
    "steamcommunity_302.cli": "90fbd363b8ddd80feff0341fbeb8b21873f6affeed72f6e47ff3142eee7c95c9",
}


class ControlError(Exception):
    pass


def regular(path, limit=None):
    path = Path(path)
    if path.is_symlink() or not stat.S_ISREG(path.stat().st_mode):
        raise ControlError("文件类型检查未通过")
    if limit is not None and path.stat().st_size > limit:
        raise ControlError("文件大小检查未通过")
    return path


def sha256(path):
    result = hashlib.sha256()
    with regular(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def verify_image(path):
    path = regular(path, 134217728)
    with path.open("rb") as stream:
        header = stream.read(12)
    if header[:5] != b"\x7fELF\x02" or header[8:11] != b"AI\x02":
        raise ControlError("加速工具安装文件格式错误")
    if sha256(path) != IMAGE_SHA256:
        raise ControlError("加速工具安装文件校验失败")


def verify_bundle(root):
    root = Path(root)
    for directory in (root, root / "usr", root / "usr/bin"):
        if directory.is_symlink() or not directory.is_dir():
            raise ControlError("加速工具目录检查失败")
    bindir = root / "usr/bin"
    manifest = json.loads(regular(bindir / "s302-service-manifest.json", 65536).read_text())
    if (manifest.get("schemaVersion"), manifest.get("version"), manifest.get("os"), manifest.get("arch")) != (1, VERSION, "linux", "amd64"):
        raise ControlError("加速工具版本不匹配")
    entries = manifest.get("resources", [])
    if len(entries) != len(RESOURCES) or {e.get("name") for e in entries} != set(RESOURCES):
        raise ControlError("加速工具资源不完整")
    for entry in entries:
        target = regular(bindir / entry["name"])
        if (entry.get("sha256") != RESOURCES[entry["name"]]
                or target.stat().st_size != entry.get("size")
                or sha256(target) != RESOURCES[entry["name"]]):
            raise ControlError("加速工具资源校验失败")
    for path in (root / "AppRun", bindir / "Steamcommunity_302", bindir / "s302-service-installer"):
        with regular(path).open("rb") as stream:
            if stream.read(5) != b"\x7fELF\x02":
                raise ControlError("加速工具运行文件格式错误")


class UnixHTTP(http.client.HTTPConnection):
    def __init__(self, path, fallback=None):
        super().__init__("s302.local", timeout=45)
        self.path = str(path)
        self.fallback = fallback

    def connect(self):
        self.sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self.sock.settimeout(self.timeout)
        try:
            self.sock.connect(self.path)
        except (PermissionError, FileNotFoundError, ConnectionRefusedError):
            self.sock.close()
            if self.fallback is None:
                raise
            # V15's official service also advertises an authenticated loopback
            # transport. Some systems restrict writes to its root-owned socket.
            self.sock = socket.create_connection(self.fallback, timeout=self.timeout)
            self.host, self.port = self.fallback


class Client:
    def __init__(self):
        uid = os.getuid()
        if uid == 0:
            raise ControlError("请用桌面用户运行 Renkit")
        runtime = Path("/run/s302") / str(uid)
        descriptor_path = regular(runtime / "control.json", 65536)
        if descriptor_path.stat().st_uid != 0 or descriptor_path.stat().st_mode & 0o022:
            raise ControlError("加速组件连接信息权限不正确")
        descriptor = json.loads(descriptor_path.read_text())
        endpoint = descriptor.get("ipc", {})
        self.socket = runtime / "control.sock"
        if (descriptor.get("schemaVersion") != 1 or descriptor.get("apiVersion") != "1.0"
                or endpoint.get("kind") != "unix" or endpoint.get("address") != str(self.socket)):
            raise ControlError("加速组件连接信息不匹配")
        info = self.socket.lstat()
        if not stat.S_ISSOCK(info.st_mode) or info.st_uid != 0:
            raise ControlError("加速组件连接权限不正确")
        self.fallback = None
        tcp = descriptor.get("tcp")
        if tcp:
            match = re.fullmatch(r"127\.0\.0\.1:([0-9]{1,5})", tcp.get("address", ""))
            if tcp.get("kind") != "tcp" or not match or not 1 <= int(match[1]) <= 65535:
                raise ControlError("加速组件备用连接信息不正确")
            self.fallback = ("127.0.0.1", int(match[1]))
        token_path = Path.home() / ".config/Steamcommunity_302/control.token"
        if descriptor.get("credentialFile") != str(token_path):
            raise ControlError("加速组件授权位置不匹配")
        info = regular(token_path, 4096).stat()
        if info.st_uid != uid or info.st_mode & 0o077:
            raise ControlError("加速组件授权文件权限不正确")
        self.token = token_path.read_text().strip()
        if not re.fullmatch(r"[A-Za-z0-9+/_-]{43}=?", self.token):
            raise ControlError("加速组件授权文件无效")
        if len(base64.b64decode(self.token + "=" * (-len(self.token) % 4), altchars=b"-_", validate=True)) != 32:
            raise ControlError("加速组件授权文件无效")

    def request(self, method, path, payload=None):
        connection = UnixHTTP(self.socket, self.fallback)
        headers = {"Authorization": "Bearer " + self.token, "Accept": "application/json"}
        body = None
        if method != "GET":
            headers["Idempotency-Key"] = "renkit-" + uuid.uuid4().hex
        if payload is not None:
            body = json.dumps(payload).encode()
            headers["Content-Type"] = "application/json"
        try:
            # Host is transport-specific in V15 (s302.local for Unix, exact
            # loopback address:port for TCP). Select before HTTP builds headers.
            connection.connect()
            connection.request(method, path, body, headers)
            response = connection.getresponse()
            data = response.read(1048577)
            if len(data) > 1048576:
                raise ControlError("加速组件响应过大")
            result = json.loads(data)
            if not 200 <= response.status < 300:
                code = result.get("error", {}).get("code", "request_failed")
                code = code if re.fullmatch(r"[a-z0-9_]{1,80}", str(code)) else "request_failed"
                raise ControlError("加速组件请求失败：" + code)
            return result
        finally:
            connection.close()

    def configure(self):
        deadline = time.monotonic() + 40
        while self.request("GET", "/v1/status").get("currentOperation"):
            if time.monotonic() >= deadline:
                raise ControlError("加速组件正在处理其他操作，请稍后重试")
            time.sleep(0.5)
        document = self.request("GET", "/v1/config")["config"]
        settings = copy.deepcopy(document["settings"])
        catalog = self.request("GET", "/v1/rules")
        available = {rule["id"] for rule in catalog["rules"]}
        if not set(RULES) <= available:
            raise ControlError("加速规则不完整，已保留原来的设置")
        settings["rules"]["enabled"] = list(dict.fromkeys(settings["rules"]["enabled"] + RULES))
        settings["engine"]["startOnDaemonLaunch"] = True
        settings["hosts"]["autoModify"] = True
        settings["hosts"]["autoBackup"] = True
        settings["dns"]["enabled"] = True
        if settings != document["settings"]:
            self.request("PATCH", "/v1/config", {"revision": document["revision"], "settings": settings})

    def certificate_status(self):
        return self.request("GET", "/v1/cert/status")["status"]

    def certificates(self):
        # Re-import through the vendor even if the system bundle already trusts
        # the CA: Steam's NSS database may have appeared since the last run.
        self.request("POST", "/v1/cert/install")
        status = self.certificate_status()
        if not status.get("generated") or status.get("trusted") != "trusted":
            raise ControlError("加速证书尚未完全生效，请在加速工具中检查安全证书")

    def engine(self, action):
        if action == "start":
            status = self.request("GET", "/v1/status")
            if status.get("engine") == "running":
                if not status.get("reloadRequired"):
                    return
                action = "reload"
        accepted = self.request("POST", "/v1/engine/" + action)
        operation = accepted.get("operation", {}).get("id")
        # Backend operations are asynchronous. A successful HTTP status alone is
        # not proof that the engine completed its network/certificate changes.
        if not isinstance(operation, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,160}", operation):
            raise ControlError("加速组件未返回操作状态")
        deadline = time.monotonic() + 45
        while time.monotonic() < deadline:
            result = self.request("GET", "/v1/operations/" + operation)["operation"]
            if result["state"] == "failed":
                raise ControlError("加速组件操作失败，请查看加速工具日志")
            if result["state"] != "running":
                expected = "stopped" if action == "stop" else "running"
                if self.request("GET", "/v1/status")["engine"] == expected:
                    return
                raise ControlError("加速组件尚未达到预期状态")
            time.sleep(0.5)
        raise ControlError("加速组件仍在处理，暂不能确认成功，请查看运行状态")

    def ready(self):
        status = self.request("GET", "/v1/status")
        document = self.request("GET", "/v1/config")["config"]
        if (status.get("engine") != "running" or status.get("reloadRequired")
                or not set(RULES) <= set(document["settings"]["rules"]["enabled"])
                or self.certificate_status().get("trusted") != "trusted"):
            raise ControlError("加速尚未准备完成")


def main():
    action = sys.argv[1]
    if action == "verify-image":
        verify_image(sys.argv[2])
        return
    if action == "verify-bundle":
        verify_bundle(sys.argv[2])
        return
    client = Client()
    if action == "configure":
        client.configure()
    elif action == "certificates":
        client.certificates()
    elif action == "remove-certificates":
        client.request("POST", "/v1/cert/remove")
    elif action in ("start", "stop"):
        client.engine(action)
    elif action == "ready":
        client.ready()
    elif action == "status":
        status = client.request("GET", "/v1/status")
        states = {"running": "运行中", "stopped": "已停止", "failed": "未能启动", "starting": "正在启动", "degraded": "部分功能不可用"}
        print("加速状态：" + states.get(status.get("engine"), "尚未准备完成"))
        print("证书状态：" + ("已生效" if client.certificate_status().get("trusted") == "trusted" else "需要修复"))
    else:
        raise ControlError("未知加速操作")


if __name__ == "__main__":
    try:
        main()
    except (ControlError, OSError, ValueError, KeyError, TypeError, http.client.HTTPException):
        # Never print arbitrary backend responses or a traceback containing auth.
        error = sys.exc_info()[1]
        print(str(error) if isinstance(error, ControlError) else "加速组件暂时不可用，请重试或查看加速工具日志。", file=sys.stderr)
        sys.exit(1)
