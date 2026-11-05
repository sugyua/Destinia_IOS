"""Verificações estáticas da configuração do servidor offline iOS.

Este teste NÃO substitui compilação com Xcode nem teste em iPhone real.
"""
import unittest
from pathlib import Path

SOURCE = (Path(__file__).resolve().parents[1]
          / "DestiniaIOS" / "Sources" / "LoopbackServer.swift")


class LoopbackConfigurationTests(unittest.TestCase):
    def test_listener_uses_only_loopback(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn("parameters.requiredInterfaceType = .loopback", source)
        self.assertIn("parameters.acceptLocalOnly = true", source)

    def test_no_double_port_binding(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertNotIn("parameters.requiredLocalEndpoint =", source)
        self.assertIn("listener = try NWListener(using: parameters, on:", source)

    def test_local_address_remains_stable_for_saves(self):
        source = SOURCE.read_text(encoding="utf-8")
        self.assertIn("private let port: UInt16 = 19406", source)
        self.assertIn("http://127.0.0.1:", source)


if __name__ == "__main__":
    unittest.main()
