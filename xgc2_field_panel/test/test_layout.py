#!/usr/bin/env python3
"""ROS-independent layout and dependency contract."""
from __future__ import annotations

import ast
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PKG = ROOT / "xgc2_field_panel"


def test_product_id() -> None:
    text = (ROOT / ".xgc2/product.yml").read_text()
    assert "id: xgc2-field-panel" in text
    assert "version: 0.1.0-1" in text


def test_package_xml_has_no_first_party_depends() -> None:
    tree = ET.parse(PKG / "package.xml")
    forbidden = (
        "xgc2_",
        "agilex_",
        "unicycle_",
        "estimator_",
        "rigid_state",
        "state_machine_msgs",
    )
    for dep in tree.findall("exec_depend"):
        name = (dep.text or "").strip()
        for needle in forbidden:
            assert needle not in name, name


def test_launch_and_scripts_parse() -> None:
    ET.parse(PKG / "launch/panel.launch")
    source = (PKG / "scripts/field_panel_node").read_text()
    ast.parse(source, filename="field_panel_node")
    assert source.splitlines()[1].startswith("# -*- coding: utf-8 -*-")
    assert "def start_stack(" in source
    assert "def stop_stack(" in source
    assert "vrpn_state" in source
    ast.parse((PKG / "scripts/vrpn_to_planar_state").read_text(), filename="vrpn_to_planar_state")
    html = (PKG / "web/index.html").read_text()
    assert "onclick=\"startStack()\"" in html
    assert "onclick=\"stopStack()\"" in html
    assert "bindTeleopHold" in html
    assert "pressed: true" in html
    assert "按住移动，松开即停" in html
    assert "/api/stack/start" in html
    assert "/api/stack/stop" in html
    assert "临时遥控" in html
    assert "/api/process/start" not in html
    assert "/api/config" in html
    assert 'id="params"' in html
    assert 'id="status"' in html
    assert 'id="control"' in html
    assert "动捕 VRPN" in html
    assert "状态估计" in html
    assert "估计 − 动捕" in html
    assert "cmd_vel" in html
    assert "开机自启" not in html
    assert "roscore" not in html
    assert "class=\"actions\"" in html
    assert "max-width" in html or "720px" in html
    assert "viewport-fit=cover" in html
    assert "100dvh" in html
    assert "touch-action: manipulation" in html
    assert "#control { order: 2;" in html
    assert "100dvh" in html
    assert html.count("id=\"stack-start\"") == 1
    assert html.count("id=\"stack-stop\"") == 1
    assert "def halt_until_stopped(" in source
    assert "def save_panel_config(" in source
    assert "def load_panel_config(" in source
    assert "def apply_teleop(" in source
    assert "_request_nmpc_hold" in source
    assert "shuttle_arrive_tol:=0.35" in source
    assert "算法在跑或正在停止，不能遥控" in source
    assert "算法运行或启停中，不能改参数" in source
    assert 'id="save-params"' in html
    assert (PKG / "web/index.html").is_file()


def test_config_persists_roundtrip() -> None:
    import importlib.machinery
    import importlib.util
    import tempfile
    import types

    path_src = PKG / "scripts/field_panel_node"
    loader = importlib.machinery.SourceFileLoader("field_panel_node", str(path_src))
    spec = importlib.util.spec_from_loader("field_panel_node", loader)
    if spec is None:
        mod = types.ModuleType("field_panel_node")
        loader.exec_module(mod)
    else:
        mod = importlib.util.module_from_spec(spec)
        loader.exec_module(mod)
    handle = tempfile.NamedTemporaryFile(suffix=".json", delete=False)
    path = handle.name
    handle.close()
    try:
        mod.STATE.vrpn_server = "10.0.0.8"
        mod.STATE.vrpn_port = 3884
        mod.STATE.tracker = "ugv1"
        mod.STATE.shuttle_x = 1.25
        mod.STATE.shuttle_y_min = -3.0
        mod.STATE.shuttle_y_max = 3.0
        mod.STATE.shuttle_speed = 0.7
        mod.STATE.nmpc_max_v = 1.1
        assert mod.save_panel_config(path)
        mod.STATE.vrpn_server = "old"
        mod.STATE.shuttle_x = 0.0
        mod.STATE.tracker = "pose_0"
        assert mod.load_panel_config(path)
        assert mod.STATE.vrpn_server == "10.0.0.8"
        assert mod.STATE.vrpn_port == 3884
        assert mod.STATE.tracker == "ugv1"
        assert mod.STATE.shuttle_x == 1.25
        assert mod.STATE.shuttle_y_min == -3.0
        assert mod.STATE.shuttle_y_max == 3.0
        assert mod.STATE.shuttle_speed == 0.7
        assert mod.STATE.nmpc_max_v == 0.7
        assert mod.STATE.nmpc_min_v == -0.7
    finally:
        Path(path).unlink(missing_ok=True)
        Path(path + ".tmp").unlink(missing_ok=True)


if __name__ == "__main__":
    test_product_id()
    test_package_xml_has_no_first_party_depends()
    test_launch_and_scripts_parse()
    test_config_persists_roundtrip()
    print("layout ok")
