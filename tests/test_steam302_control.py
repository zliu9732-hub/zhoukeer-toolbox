#!/usr/bin/env python3
"""Offline regression checks: no privilege, external requests or Linux programs."""
import copy
import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from unittest.mock import MagicMock

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("steam302_control", ROOT / "scripts/steam302_control.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class FakeClient(module.Client):
    def __init__(self):
        self.calls = []
        self.document = {"revision": 19, "settings": {
            "rules": {"enabled": ["customer-rule"], "quicEnabled": ["customer-rule"], "autoUpdate": False},
            "engine": {"startOnDaemonLaunch": False, "httpPort": 80, "httpsPort": 443},
            "hosts": {"autoModify": False, "autoBackup": False},
            "dns": {"enabled": False, "upstreams": ["customer-dns"]},
            "cdn": {"custom": "preserve"}, "ech": {"enabled": False}}}
        self.catalog = [{"id": name} for name in module.RULES]
        self.certificate = {"generated": True, "trusted": "trusted"}
        self.engine_state = "stopped"
        self.reload = False
        self.operation_state = "completed"
        self.final_state = "running"

    def request(self, method, path, payload=None):
        self.calls.append((method, path, copy.deepcopy(payload)))
        if path == "/v1/config":
            if method == "PATCH":
                self.document = copy.deepcopy(payload)
            return {"config": copy.deepcopy(self.document)}
        if path == "/v1/status":
            return {"engine": self.engine_state, "reloadRequired": self.reload, "currentOperation": None}
        if path == "/v1/rules":
            return {"rules": self.catalog}
        if path == "/v1/cert/status":
            return {"status": self.certificate}
        if path == "/v1/cert/install":
            return {"status": self.certificate}
        if path.startswith("/v1/engine/"):
            return {"requestId": "test-request", "operation": {"id": "op_test-1", "state": "running"}}
        if path == "/v1/operations/op_test-1":
            self.engine_state = self.final_state
            self.reload = False
            return {"operation": {"state": self.operation_state}}
        raise AssertionError((method, path))


class ControlTests(unittest.TestCase):
    def test_config_preserves_custom_rules_dns_cdn_and_quic(self):
        client = FakeClient()
        client.configure()
        settings = client.document["settings"]
        self.assertEqual(settings["rules"]["enabled"], ["customer-rule"] + module.RULES)
        self.assertEqual(settings["dns"]["upstreams"], ["customer-dns"])
        self.assertEqual(settings["cdn"], {"custom": "preserve"})
        self.assertEqual(settings["rules"]["quicEnabled"], ["customer-rule"])
        client.calls.clear()
        client.configure()
        self.assertFalse(any(call[0] == "PATCH" for call in client.calls))

    def test_missing_rule_does_not_write_configuration(self):
        client = FakeClient()
        client.catalog.pop()
        with self.assertRaises(module.ControlError):
            client.configure()
        self.assertFalse(any(call[0] == "PATCH" for call in client.calls))

    def test_partial_unknown_or_missing_certificate_fails(self):
        for trust in ("partial", "unknown", "not_trusted", None):
            client = FakeClient()
            client.certificate["trusted"] = trust
            with self.assertRaises(module.ControlError):
                client.certificates()
        client = FakeClient()
        client.certificates()
        self.assertIn(("POST", "/v1/cert/install", None), client.calls)

    def test_engine_waits_for_actual_state_and_reloads_changed_config(self):
        client = FakeClient()
        client.engine_state = "running"
        client.reload = True
        client.engine("start")
        self.assertIn(("POST", "/v1/engine/reload", None), client.calls)
        client = FakeClient()
        client.final_state = "stopped"
        with self.assertRaises(module.ControlError):
            client.engine("start")

    def test_http_acceptance_and_failed_operation_are_not_success(self):
        client = FakeClient()
        client.operation_state = "failed"
        with self.assertRaises(module.ControlError):
            client.engine("start")
        self.assertTrue(any(call[1].startswith("/v1/operations/") for call in client.calls))

    def test_readiness_requires_engine_rules_certificate_and_applied_config(self):
        client = FakeClient()
        client.configure()
        client.engine_state = "running"
        client.ready()
        for value in ("partial", "not_trusted"):
            client.certificate["trusted"] = value
            with self.assertRaises(module.ControlError):
                client.ready()
        client.certificate["trusted"] = "trusted"
        client.reload = True
        with self.assertRaises(module.ControlError):
            client.ready()

    def test_corrupt_image_and_symlinks_rejected_before_execution(self):
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "image"
            path.write_bytes(b"<html>not an installer</html>")
            with self.assertRaises(module.ControlError):
                module.verify_image(path)
            link = Path(temporary) / "link"
            link.symlink_to(path)
            with self.assertRaises(module.ControlError):
                module.verify_image(link)

    def test_transport_uses_vendors_exact_host_and_only_loopback_fallback(self):
        local_socket = MagicMock()
        with patch.object(module.socket, "socket", return_value=local_socket):
            connection = module.UnixHTTP("/test/control.sock", ("127.0.0.1", 12345))
            connection.connect()
            self.assertEqual(connection.host, "s302.local")
            local_socket.connect.assert_called_once_with("/test/control.sock")
        local_socket = MagicMock()
        local_socket.connect.side_effect = PermissionError("mock restricted Unix socket")
        fallback = MagicMock()
        with patch.object(module.socket, "socket", return_value=local_socket), patch.object(module.socket, "create_connection", return_value=fallback) as connect:
            connection = module.UnixHTTP("/test/control.sock", ("127.0.0.1", 12345))
            connection.connect()
            self.assertEqual((connection.host, connection.port), ("127.0.0.1",12345))
            connect.assert_called_once_with(("127.0.0.1",12345), timeout=45)

    def test_frontend_facade_operation_id_is_not_mistaken_for_raw_api(self):
        client = FakeClient()
        original = client.request
        def facade(method, path, payload=None):
            if path.startswith("/v1/engine/"):
                return {"operationId": "facade-id"}
            return original(method, path, payload)
        client.request = facade
        with self.assertRaises(module.ControlError):
            client.engine("start")

    def test_client_never_uses_external_transport_or_insecure_tls(self):
        source = (ROOT / "scripts/steam302_control.py").read_text()
        self.assertIn("socket.AF_UNIX", source)
        self.assertNotIn("HTTPSConnection", source)
        self.assertNotIn("sslVerify", source)
        self.assertNotIn("CERT_NONE", source)
        self.assertIn('self.fallback = ("127.0.0.1", int(match[1]))', source)


if __name__ == "__main__":
    unittest.main()
