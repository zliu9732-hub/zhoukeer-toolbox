// SPDX-License-Identifier: BSD-3-Clause
// Copyright (c) 2026 Rayekkk
// https://github.com/Rayekkk/LeGo2BrightnessFix

import { callable, definePlugin, toaster, useQuickAccessVisible } from "@decky/api";
import {
  ButtonItem,
  Field,
  PanelSection,
  PanelSectionRow,
  Spinner,
  staticClasses,
  ToggleField,
} from "@decky/ui";
import { FC, Fragment, useCallback, useEffect, useState } from "react";

type PanelMode = "gamma22" | "pq" | "hybrid";

// One upside and one downside each, because that is the whole decision. The
// numbers come from this panel: a ~471 nit ceiling on the eDP AUX luminance
// control, against the 1100 nit peak the EDID advertises for a 10% window.
const MODE_INFO: Record<PanelMode, { label: string; pro: string; con: string }> = {
  gamma22: {
    label: "伽马 2.2",
    pro: "系统亮度滑块会直接控制面板，因此任何亮度下黑色都能保持纯黑。",
    con: "HDR 会按面板约 471 尼特的上限进行色调映射，高光效果会减弱。",
  },
  pq: {
    label: "PQ 模式",
    pro: "HDR 可达到面板完整的 1100 尼特峰值，并按内容母版的绝对亮度显示。",
    con: "面板会忽略硬件亮度控制；调暗只会淡化画面，暗部可能发灰。",
  },
  hybrid: {
    label: "混合模式",
    pro: "日常使用伽马 2.2，仅在游戏输出 HDR 时切换到 PQ，兼顾两者。",
    con: "每次在 HDR 与 SDR 间切换时，屏幕会短暂黑一下。",
  },
};

// Hybrid first and recommended: it is the only one that does not trade away
// something the user would notice every day.
const RECOMMENDED: PanelMode = "hybrid";
const MODE_ORDER: PanelMode[] = ["hybrid", "pq", "gamma22"];

const modeLabel = (m: PanelMode) =>
  m === RECOMMENDED ? `${MODE_INFO[m].label}（推荐）` : MODE_INFO[m].label;

interface State {
  // Setup gate
  panel_mode: PanelMode | null;
  active_mode: PanelMode | null;
  setup_done: boolean;
  setup_note: string;
  setup_error: string;
  restart_pending: boolean;
  restart_error: string;
  // Hybrid half
  hybrid_reason: string;
  hdr_now: boolean;
  // Brightness half
  panel_ok: boolean;
  panel_desc: string;
  backlight: string;
  enabled: boolean;
  active: boolean;
  reason: string;
  nits: number;
  max_nits: number;
  // EDID half
  edid_fix: boolean;
  edid_patched: boolean;
  edid_reason: string;
  edid_game_nits: number;
}

interface UpdateInfo {
  current_version?: string;
  latest_version?: string;
  update_available?: boolean;
  download_url?: string;
  asset_name?: string;
  error?: string;
}

const getState = callable<[], State>("get_state");
const setEnabled = callable<[boolean], State>("set_enabled");
const setEdidFix = callable<[boolean], State>("set_edid_fix");
const runSetup = callable<[string], State>("run_setup");
const setPanelMode = callable<[string], State>("set_panel_mode");
const restartSession = callable<[], State>("restart_session");
const getVersion = callable<[], { version: string }>("get_version");
const checkForUpdates = callable<[], UpdateInfo>("check_for_updates");
const performUpdate = callable<
  [string, string],
  { success: boolean; path?: string; error?: string }
>("perform_update");

const notify = (title: string, body: string) =>
  toaster.toast({ title, body, duration: 5000 });

// ── Updates ────────────────────────────────────────────────────────────────────
const UpdateSection: FC = () => {
  const [info, setInfo] = useState<UpdateInfo | null>(null);
  const [version, setVersion] = useState("");
  const [checking, setChecking] = useState(false);
  const [downloading, setDownloading] = useState(false);
  const [downloadPath, setDownloadPath] = useState<string | null>(null);

  // Read straight from the manifest so the installed version is on screen
  // before anyone presses the button, rather than only after a network call.
  useEffect(() => {
    let active = true;
    getVersion()
      .then((v) => { if (active) setVersion(v.version ?? ""); })
      .catch(() => undefined);
    return () => { active = false; };
  }, []);

  const check = useCallback(async () => {
    setChecking(true);
    setInfo(null);
    setDownloadPath(null);
    try {
      setInfo(await checkForUpdates());
    } catch (e) {
      const msg = e instanceof Error ? e.message : String(e);
      notify("检查更新失败", msg);
      setInfo({ error: msg });
    } finally {
      setChecking(false);
    }
  }, []);

  const download = useCallback(async () => {
    if (!info?.download_url || !info?.asset_name) {
      notify("无法下载", "此版本暂时没有可安装的 ZIP 文件。");
      return;
    }
    setDownloading(true);
    try {
      const res = await performUpdate(info.download_url, info.asset_name);
      if (res.success && res.path) setDownloadPath(res.path);
      else {
        setInfo({ ...info, error: res.error });
        notify("下载失败", res.error ?? "未知错误");
      }
    } catch (e) {
      notify("下载失败", e instanceof Error ? e.message : String(e));
    } finally {
      setDownloading(false);
    }
  }, [info]);

  return (
    <PanelSection title="更新">
      <PanelSectionRow>
          <Field label="已安装版本" focusable>
          {`v${(info?.current_version ?? version) || "?"}`}
        </Field>
      </PanelSectionRow>

      {info?.latest_version && !info.error && (
        <PanelSectionRow>
          <Field label="最新版本" focusable>{`v${info.latest_version}`}</Field>
        </PanelSectionRow>
      )}

      {info?.error && (
        <PanelSectionRow>
          <Field label="错误" description={info.error} />
        </PanelSectionRow>
      )}

      {info && !info.error && !info.update_available && !downloadPath && (
        <PanelSectionRow>
          <Field label="已是最新版本" />
        </PanelSectionRow>
      )}

      {info?.update_available && info.download_url && info.asset_name && !downloadPath && (
        <PanelSectionRow>
          <ButtonItem layout="below" onClick={download} disabled={downloading}>
            {downloading ? "正在下载…" : `下载 v${info.latest_version}`}
          </ButtonItem>
        </PanelSectionRow>
      )}

      {downloadPath && (
        <PanelSectionRow>
          <Field
            label="已下载"
            description={
              `${downloadPath} - 安装方法：在 Decky 的开发者选项中卸载 ` +
              "LeGo2 亮度修复，然后选择“从 ZIP 安装插件”并选取该文件。" +
              "你的设置会保留。"
            }
          />
        </PanelSectionRow>
      )}

      <PanelSectionRow>
        <ButtonItem layout="below" onClick={check} disabled={checking || downloading}>
          {checking ? "正在检查…" : "检查更新"}
        </ButtonItem>
      </PanelSectionRow>
    </PanelSection>
  );
};

// ── Mode picker ────────────────────────────────────────────────────────────────
const ProCon: FC<{ mode: PanelMode }> = ({ mode }) => (
  <div style={{ fontSize: "0.75em", lineHeight: 1.35, padding: "0 16px 10px" }}>
    <div style={{ color: "#5ee07a" }}>{`+ ${MODE_INFO[mode].pro}`}</div>
    <div style={{ color: "#ff7b72" }}>{`- ${MODE_INFO[mode].con}`}</div>
  </div>
);

/** One button plus the two lines that justify it. */
const ModeChoice: FC<{
  mode: PanelMode;
  busy: boolean;
  onPick: (m: PanelMode) => void;
}> = ({ mode, busy, onPick }) => (
  <Fragment>
    <PanelSectionRow>
      <ButtonItem layout="below" onClick={() => onPick(mode)} disabled={busy}>
        {modeLabel(mode)}
      </ButtonItem>
    </PanelSectionRow>
    <PanelSectionRow>
      <ProCon mode={mode} />
    </PanelSectionRow>
  </Fragment>
);

// ── Main content ───────────────────────────────────────────────────────────────
const Content: FC = () => {
  const visible = useQuickAccessVisible();
  const [state, setState] = useState<State | null>(null);
  const [busy, setBusy] = useState(false);
  // Both lists start folded away: on first run the recommendation is the whole
  // point, and afterwards the mode is a decision already made.
  const [showOthers, setShowOthers] = useState(false);
  const [showSwitch, setShowSwitch] = useState(false);

  const refresh = useCallback(async () => {
    try {
      setState(await getState());
    } catch {
      /* backend not up yet; the next tick will pick it up */
    }
  }, []);

  // Only poll while the panel is actually on screen. The backend keeps working
  // either way - this is just what the user sees.
  useEffect(() => {
    refresh();
    if (!visible) return;
    const id = setInterval(refresh, 1000);
    return () => clearInterval(id);
  }, [visible, refresh]);

  const toggle = useCallback(
    async (fn: (v: boolean) => Promise<State>, key: keyof State, value: boolean) => {
      setState((s) => (s ? { ...s, [key]: value } : s));
      try {
        setState(await fn(value));
      } catch {
        refresh();
      }
    },
    [refresh],
  );

  const setup = useCallback(async (mode: PanelMode) => {
    setBusy(true);
    try {
      const next = await runSetup(mode);
      setState(next);
      if (next.setup_error) notify("设置失败", next.setup_error);
    } catch (e) {
      notify("设置失败", e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }, []);

  const changeMode = useCallback(async (mode: PanelMode) => {
    setBusy(true);
    try {
      const next = await setPanelMode(mode);
      setState(next);
      if (next.setup_error) notify("无法切换模式", next.setup_error);
    } catch (e) {
      notify("无法切换模式", e instanceof Error ? e.message : String(e));
    } finally {
      setBusy(false);
    }
  }, []);

  const restart = useCallback(async () => {
    setBusy(true);
    try {
      // If this returns at all, the session did not go down - so surface
      // whatever the backend reported instead of leaving a dead button.
      setState(await restartSession());
    } catch {
      /* the session going down mid-call is the expected outcome */
    } finally {
      setBusy(false);
    }
  }, []);

  if (!state) {
    return (
      <PanelSection>
        <PanelSectionRow>
          <Spinner />
        </PanelSectionRow>
      </PanelSection>
    );
  }

  // Nothing works until gamescope has the display script: without it the panel
  // is either stock or, far more often on this device, still carrying the
  // gamma 2.2 workaround that takes it out of PQ entirely. Showing the normal
  // controls before that point would just look broken.
  // No mode chosen yet. Nothing is installed on the user's behalf before this,
  // because every option trades away something they may care about.
  if (!state.panel_mode) {
    return (
      <PanelSection title="选择显示模式">
        <PanelSectionRow>
          <Field
            description={
              "请选择 Legion Go 2 OLED 面板的驱动方式。这会安装一个 " +
              "Gamescope 显示脚本并替换现有的该面板脚本；旧脚本会保留为 " +
              ".backup 文件。你可以随时更改选择。"
            }
          />
        </PanelSectionRow>
        <ModeChoice mode={RECOMMENDED} busy={busy} onPick={setup} />

        {state.setup_error && (
          <PanelSectionRow>
            <Field label="设置失败" description={state.setup_error} />
          </PanelSectionRow>
        )}

        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={() => setShowOthers((v) => !v)}
            disabled={busy}
          >
            {showOthers ? "隐藏其他选项" : "其他选项"}
          </ButtonItem>
        </PanelSectionRow>

        {showOthers &&
          MODE_ORDER.filter((m) => m !== RECOMMENDED).map((m) => (
            <ModeChoice key={m} mode={m} busy={busy} onPick={setup} />
          ))}
      </PanelSection>
    );
  }

  if (!state.setup_done) {
    return (
      <PanelSection title="设置">
        <PanelSectionRow>
          <Field
            label={`需要显示脚本（${MODE_INFO[state.panel_mode].label}）`}
            description={
              "此模式所需脚本尚未就位。安装会替换现有的该面板脚本，旧脚本会以 .backup 文件保留。"
            }
          />
        </PanelSectionRow>
        {state.setup_note && (
          <PanelSectionRow>
            <Field label="状态" description={state.setup_note} />
          </PanelSectionRow>
        )}
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={() => setup(state.panel_mode as PanelMode)}
            disabled={busy}
          >
            {busy ? "正在安装…" : "安装显示修复"}
          </ButtonItem>
        </PanelSectionRow>
      </PanelSection>
    );
  }

  if (state.restart_pending) {
    return (
      <PanelSection title="需要重启">
        <PanelSectionRow>
          <Field
            label="显示脚本已安装"
            description={
              "Gamescope 只会在启动时读取显示脚本。因此需重启游戏模式才能生效；这会关闭 Steam 后立即重新打开。"
            }
          />
        </PanelSectionRow>
        {state.restart_error && (
          <PanelSectionRow>
            <Field
              label="无法重启"
              description={
                `${state.restart_error}。请手动重启游戏模式：Steam 菜单 → 电源 → 切换到桌面模式后再切回，或直接重启设备。`
              }
            />
          </PanelSectionRow>
        )}
        <PanelSectionRow>
          <ButtonItem layout="below" onClick={restart} disabled={busy}>
            重启游戏模式
          </ButtonItem>
        </PanelSectionRow>
        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={() => setShowSwitch((v) => !v)}
            disabled={busy}
          >
            {showSwitch ? "保持当前选择" : "更改显示模式"}
          </ButtonItem>
        </PanelSectionRow>
        {showSwitch &&
          MODE_ORDER.filter((m) => m !== state.panel_mode).map((m) => (
            <ModeChoice key={m} mode={m} busy={busy} onPick={changeMode} />
          ))}
      </PanelSection>
    );
  }

  return (
    <>
      <PanelSection title="显示器">
        <PanelSectionRow>
          <Field
            label={state.panel_desc || "未知面板"}
            description={
              state.backlight
                ? `背光：${state.backlight}` +
                  (state.max_nits ? ` · 最高 ${state.max_nits.toFixed(0)} 尼特` : "")
                : undefined
            }
          />
        </PanelSectionRow>
      </PanelSection>

      <PanelSection title="显示模式">
        <PanelSectionRow>
          <Field label="模式" focusable>
            {MODE_INFO[state.panel_mode].label}
          </Field>
        </PanelSectionRow>

        {state.panel_mode === "hybrid" && (
          <PanelSectionRow>
          <Field label="当前面板模式" description={state.hybrid_reason} focusable>
            {state.hdr_now ? "PQ 模式" : "伽马 2.2"}
            </Field>
          </PanelSectionRow>
        )}

        <PanelSectionRow>
          <ButtonItem
            layout="below"
            onClick={() => setShowSwitch((v) => !v)}
            disabled={busy}
          >
            {showSwitch ? "取消" : "切换显示模式"}
          </ButtonItem>
        </PanelSectionRow>

        {showSwitch &&
          MODE_ORDER.filter((m) => m !== state.panel_mode).map((m) => (
            <ModeChoice
              key={m}
              mode={m}
              busy={busy}
              onPick={(picked) => {
                setShowSwitch(false);
                changeMode(picked);
              }}
            />
          ))}
      </PanelSection>

      <PanelSection title="亮度滑块">
        {state.panel_ok ? (
          <>
            <PanelSectionRow>
              <ToggleField
                label="启用"
                description="面板处于 HDR/PQ 时，将 Steam 亮度滑块的值转交给 Gamescope。"
                checked={state.enabled}
                onChange={(v) => toggle(setEnabled, "enabled", v)}
              />
            </PanelSectionRow>

            <PanelSectionRow>
              <Field label="状态" description={state.reason} focusable>
                {state.active ? "已生效" : "待命"}
              </Field>
            </PanelSectionRow>

            {state.active && (
              <PanelSectionRow>
                <Field label="亮度" focusable>
                  {`${state.nits.toFixed(1)} / ${state.max_nits.toFixed(0)} 尼特`}
                </Field>
              </PanelSectionRow>
            )}
          </>
        ) : (
          <PanelSectionRow>
            <Field
              label="不适用"
              description={
                "此功能仅在已知会于 HDR/PQ 下忽略背光控制的面板上运行，因此当前没有修改任何设置。"
              }
            />
          </PanelSectionRow>
        )}
      </PanelSection>

      <PanelSection title="游戏 EDID">
        <PanelSectionRow>
          <ToggleField
            label="启用"
            description="从 Gamescope 交给游戏的 EDID 中移除 DXVK 无法解析的 DisplayID 区块。"
            checked={state.edid_fix}
            onChange={(v) => toggle(setEdidFix, "edid_fix", v)}
          />
        </PanelSectionRow>

        <PanelSectionRow>
          <Field label="状态" description={state.edid_reason} focusable>
            {state.edid_patched ? "已应用" : "待命"}
          </Field>
        </PanelSectionRow>

        {state.edid_patched && state.edid_game_nits > 0 && (
          <PanelSectionRow>
            <Field
              label="游戏读取值"
              description="未启用时，游戏会回退为 DXVK 的 1499 尼特占位值和通用原色。"
              focusable
            >
              {`${state.edid_game_nits.toFixed(0)} 尼特`}
            </Field>
          </PanelSectionRow>
        )}
      </PanelSection>

      <UpdateSection />
    </>
  );
};

// ── Icon ───────────────────────────────────────────────────────────────────────
const BrightnessIcon: FC = () => (
  <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"
    style={{ width: "1em", height: "1em" }}>
    <path d="M12 7a5 5 0 1 0 0 10 5 5 0 0 0 0-10zm0-6h-1v3h2V1h-1zm0 19h-1v3h2v-3h-1zM1 11v2h3v-2H1zm19 0v2h3v-2h-3zM4.2 4.2 3.5 4.9l2.1 2.1.7-.7-2.1-2.1zm13 13-.7.7 2.1 2.1.7-.7-2.1-2.1zM6.3 17.9l-2.1 2.1.7.7 2.1-2.1-.7-.7zm13-13-2.1 2.1.7.7 2.1-2.1-.7-.7z" />
  </svg>
);

export default definePlugin(() => ({
  name: "LeGo2 亮度修复",
  titleView: <div className={staticClasses.Title}>LeGo2 亮度修复</div>,
  content: <Content />,
  icon: <BrightnessIcon />,
  onDismount() {
    /* the backend releases the atom and restores the EDID in _unload */
  },
}));
