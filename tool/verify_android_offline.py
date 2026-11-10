"""Verifica listas e, com --items, a Fase 2 offline no app normal, sem reset/uninstall."""

import argparse
import json
import re
import subprocess
import sys
import time
import uuid
import xml.etree.ElementTree as ET
from pathlib import Path


PACKAGE = "br.com.rodolpho.marketlist"


class AndroidCheck:
    def __init__(self, adb, serial, output):
        self.command = [adb, "-s", serial]
        self.output = output
        self.remote_xml = f"/data/local/tmp/marketlist_{uuid.uuid4().hex}.xml"

    def adb(self, *args, binary=False, check=True):
        result = subprocess.run(self.command + list(args), capture_output=True, timeout=30)
        if check and result.returncode:
            raise RuntimeError(f"ADB falhou em {args[0]} (código {result.returncode}).")
        return result.stdout if binary else result.stdout.decode("utf-8", errors="replace").strip()

    def snapshot(self):
        self.adb("shell", "rm", "-f", self.remote_xml)
        self.adb("shell", "uiautomator", "dump", "--compressed", self.remote_xml)
        xml = self.adb("exec-out", "cat", self.remote_xml)
        root = ET.fromstring(xml)
        nodes = [node.attrib for node in root.iter("node") if node.get("package") == PACKAGE]
        if not nodes:
            raise RuntimeError("MarketList não está visível; mantenha o app desbloqueado em primeiro plano.")
        return nodes

    @staticmethod
    def has_label(node, label):
        return any(label in node.get(key, "").splitlines() for key in ("text", "content-desc"))

    def wait_for(self, predicate, timeout=20):
        deadline = time.monotonic() + timeout
        last_error = None
        while time.monotonic() < deadline:
            try:
                nodes = self.snapshot()
                if predicate(nodes):
                    return nodes
            except (RuntimeError, ET.ParseError) as error:
                last_error = error
            time.sleep(0.25)
        raise RuntimeError(f"A tela esperada não apareceu. {last_error or ''}")

    def tap_node(self, node):
        if node.get("enabled") != "true":
            raise RuntimeError("O controle esperado está desabilitado.")
        bounds = re.fullmatch(r"\[(\d+),(\d+)\]\[(\d+),(\d+)\]", node.get("bounds", ""))
        if not bounds:
            raise RuntimeError("Controle sem limites de tela válidos.")
        left, top, right, bottom = map(int, bounds.groups())
        self.adb("shell", "input", "tap", str((left + right) // 2), str((top + bottom) // 2))

    def tap_label(self, label):
        nodes = self.wait_for(lambda nodes: any(self.has_label(node, label) for node in nodes))
        candidates = [node for node in nodes if self.has_label(node, label)]
        candidates.sort(key=lambda node: node.get("clickable") != "true")
        self.tap_node(candidates[0])

    def edit(self, index, text):
        nodes = self.wait_for(lambda nodes: len([node for node in nodes if node.get("class") == "android.widget.EditText"]) == 2)
        fields = [node for node in nodes if node.get("class") == "android.widget.EditText"]
        fields.sort(key=lambda node: int(re.findall(r"\d+", node["bounds"])[1]))
        self.tap_node(fields[index])
        self.adb("shell", "input", "text", text)

    def setting(self, name):
        return self.adb("shell", "settings", "get", "global", name)

    def screenshot(self, name):
        (self.output / name).write_bytes(self.adb("exec-out", "screencap", "-p", binary=True))

    def start(self):
        self.adb("shell", "am", "start", "-W", "-n", f"{PACKAGE}/.MainActivity")

    def home_with(self, name):
        return self.wait_for(lambda nodes: any(self.has_label(node, name) for node in nodes)
                             and not any(node.get("class") == "android.widget.EditText" for node in nodes))

    def remove_test_list(self, name):
        self.adb("shell", "am", "force-stop", PACKAGE)
        self.start()
        nodes = self.home_with("Minhas listas")
        if not any(self.has_label(node, name) for node in nodes):
            return
        self.tap_label(f"Excluir lista {name}")
        self.wait_for(lambda nodes: any(self.has_label(node, f"Excluir “{name}”?") for node in nodes))
        self.tap_label("Excluir")
        self.wait_for(lambda nodes: any(self.has_label(node, "Minhas listas") for node in nodes)
                      and not any(self.has_label(node, name) for node in nodes)
                      and not any(self.has_label(node, f"Excluir “{name}”?") for node in nodes))


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--adb", required=True)
    parser.add_argument("--serial", required=True)
    parser.add_argument("--inspect", action="store_true", help="Somente inspeciona controles do MarketList.")
    parser.add_argument("--run", action="store_true", help="Autoriza teste com modo avião/Wi-Fi temporários.")
    parser.add_argument("--items", action="store_true", help="Inclui produtos/quantidades/remoção/ordem da Fase 2.")
    options = parser.parse_args()
    if options.inspect == options.run:
        parser.error("Escolha exatamente --inspect ou --run.")
    if options.items and not options.run:
        parser.error("--items exige --run.")
    output = Path(__file__).resolve().parents[1] / "build" / ("offline_verification_f2" if options.items else "offline_verification")
    output.mkdir(parents=True, exist_ok=True)
    check = AndroidCheck(options.adb, options.serial, output)
    if options.inspect:
        try:
            nodes = check.snapshot()
            print(json.dumps(nodes, ensure_ascii=False, indent=2))
            check.screenshot("home_before_test.png")
        finally:
            check.adb("shell", "rm", "-f", check.remote_xml, check=False)
        return

    name = f"TesteOffline{'F2' if options.items else 'F1'}_{uuid.uuid4().hex[:8]}"
    report = {"test_list": name, "persisted_after_restart": False, "cleanup_ok": False}
    original_airplane = check.setting("airplane_mode_on")
    original_wifi = check.setting("wifi_on")
    original_stay_on = check.setting("stay_on_while_plugged_in")
    if original_airplane not in ("0", "1") or original_wifi not in ("0", "1"):
        raise RuntimeError("Estado de rede transitório/desconhecido; teste não iniciado.")
    if not original_stay_on.isdigit():
        raise RuntimeError("Estado de tela desconhecido; teste não iniciado.")
    nodes = check.home_with("Minhas listas")
    if any(node.get("class") == "android.widget.EditText" for node in nodes):
        raise RuntimeError("Há um formulário aberto; teste não iniciado.")
    report["original_airplane"] = original_airplane
    report["original_wifi"] = original_wifi
    report["original_stay_on"] = original_stay_on
    (output / "result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    started = False
    try:
        check.adb("shell", "svc", "power", "stayon", "usb")
        check.adb("shell", "cmd", "connectivity", "airplane-mode", "enable")
        check.adb("shell", "svc", "wifi", "disable")
        deadline = time.monotonic() + 20
        while time.monotonic() < deadline:
            connectivity = check.adb("shell", "dumpsys", "connectivity")
            if (check.setting("airplane_mode_on") == "1" and check.setting("wifi_on") == "0"
                    and "Active default network: none" in connectivity):
                break
            time.sleep(0.5)
        else:
            raise RuntimeError("Não foi possível confirmar ausência de rede padrão.")
        report["offline_confirmed"] = True
        started = True
        check.tap_label("Nova lista")
        check.edit(0, name)
        check.edit(1, "123,45")
        check.screenshot("form_keyboard.png")
        check.tap_label("Criar lista")
        check.home_with(name)
        if options.items:
            check.tap_label(name)
            check.home_with(name)
            for product, quantity in [("CarneTeste", None), ("LeiteTeste", "5"), ("RemovidoTeste", "2")]:
                check.tap_label("Adicionar produto")
                check.edit(0, product)
                if quantity is not None:
                    check.edit(1, quantity)
                check.screenshot("item_form_keyboard.png")
                check.tap_label("Salvar produto")
                check.home_with(name)
            check.tap_label("RemovidoTeste")
            check.tap_label("Remover produto")
            check.wait_for(lambda nodes: not any(check.has_label(node, "RemovidoTeste") for node in nodes)
                           and not any(node.get("class") == "android.widget.EditText" for node in nodes))
        original_pid = check.adb("shell", "pidof", PACKAGE)
        if not original_pid:
            raise RuntimeError("Processo inicial não identificado.")
        check.adb("shell", "am", "force-stop", PACKAGE)
        check.start()
        nodes = check.home_with(name)
        new_pid = check.adb("shell", "pidof", PACKAGE)
        if not new_pid or new_pid == original_pid:
            raise RuntimeError("Não foi comprovada a troca de processo.")
        if not any(check.has_label(node, "Orçamento: R$ 123,45") for node in nodes):
            raise RuntimeError("Orçamento não recuperado na interface.")
        if options.items:
            check.tap_label(name)
            nodes = check.home_with("CarneTeste")
            for label in ("LeiteTeste", "Pendente · Planejado: 5", "Pendente · Quantidade não informada"):
                if not any(check.has_label(node, label) for node in nodes):
                    raise RuntimeError(f"Dado de produto não recuperado: {label}")
            if any(check.has_label(node, "RemovidoTeste") for node in nodes):
                raise RuntimeError("Produto removido reapareceu após reinício.")
            first = next(i for i, node in enumerate(nodes) if check.has_label(node, "CarneTeste"))
            second = next(i for i, node in enumerate(nodes) if check.has_label(node, "LeiteTeste"))
            if first >= second:
                raise RuntimeError("Ordem de cadastro não foi preservada.")
            report.update(items_persisted=True, removed_item_hidden=True, order_preserved=True)
        report.update(persisted_after_restart=True, original_pid=original_pid, new_pid=new_pid)
        check.screenshot("after_restart_offline.png")
    except Exception as error:
        report["error"] = str(error)
    finally:
        try:
            if started:
                check.remove_test_list(name)
            report["cleanup_ok"] = True
        except Exception as error:
            report["cleanup_error"] = str(error)
        finally:
            check.adb("shell", "cmd", "connectivity", "airplane-mode",
                      "enable" if original_airplane == "1" else "disable", check=False)
            check.adb("shell", "svc", "wifi", "enable" if original_wifi == "1" else "disable", check=False)
            check.adb("shell", "settings", "put", "global", "stay_on_while_plugged_in", original_stay_on, check=False)
            deadline = time.monotonic() + 10
            while time.monotonic() < deadline:
                if (check.setting("airplane_mode_on") == original_airplane
                        and check.setting("wifi_on") == original_wifi):
                    break
                time.sleep(0.25)
            report["restored_airplane"] = check.setting("airplane_mode_on")
            report["restored_wifi"] = check.setting("wifi_on")
            report["restored_stay_on"] = check.setting("stay_on_while_plugged_in")
            report["network_settings_restored"] = (
                report["restored_airplane"] == original_airplane and report["restored_wifi"] == original_wifi)
            report["screen_setting_restored"] = report["restored_stay_on"] == original_stay_on
            check.adb("shell", "rm", "-f", check.remote_xml, check=False)
            (output / "result.json").write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
            print(json.dumps(report, ensure_ascii=False))
    if not (report["persisted_after_restart"] and report["cleanup_ok"]
            and report["network_settings_restored"] and report["screen_setting_restored"]):
        raise SystemExit(1)


if __name__ == "__main__":
    main()
