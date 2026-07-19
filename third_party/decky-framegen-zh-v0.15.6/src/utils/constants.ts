// Common types for the application

export interface ResultType {
  status: string;
  message?: string;
  output?: string;
}

export interface GameType {
  appid: number;
  name: string;
}

// Common style definitions
export const STYLES = {
  resultBox: {
    padding: '12px',
    marginTop: '16px',
    backgroundColor: 'var(--decky-selected-ui-bg)',
    borderRadius: '8px',
    border: '1px solid var(--decky-border-color)',
    fontSize: '14px'
  },
  statusInstalled: { 
    color: '#22c55e',
    fontWeight: 'bold',
    fontSize: '14px'
  },
  statusNotInstalled: { 
    color: '#f97316',
    fontWeight: 'bold',
    fontSize: '14px'
  },
  statusSuccess: { color: "#22c55e" },
  statusError: { color: "#ef4444" },
  preWrap: { whiteSpace: "pre-wrap" as const },
  instructionCard: {
    padding: '14px',
    backgroundColor: 'var(--decky-selected-ui-bg)',
    borderRadius: '8px',
    border: '1px solid var(--decky-border-color)',
    marginTop: '8px',
    fontSize: '13px',
    lineHeight: '1.4'
  }
};

// Proxy DLL name options for OptiScaler injection
export const PROXY_DLL_OPTIONS = [
  { value: "dxgi.dll", label: "dxgi.dll（默认）", hint: "适用于大多数 DX12 游戏。" },
  { value: "winmm.dll", label: "winmm.dll", hint: "当 dxgi.dll 与游戏已有文件冲突时使用。" },
  { value: "version.dll", label: "version.dll", hint: "常用备用项，适配许多启动器。" },
  { value: "dbghelp.dll", label: "dbghelp.dll", hint: "用于调试辅助挂钩路径。" },
  { value: "winhttp.dll", label: "winhttp.dll", hint: "其他 DLL 名称冲突时使用。" },
  { value: "wininet.dll", label: "wininet.dll", hint: "其他 DLL 名称冲突时使用。" },
  { value: "OptiScaler.asi", label: "OptiScaler.asi", hint: "用于 ASI 加载器；游戏需已安装 ASI 加载器。" },
] as const;

export type ProxyDllValue = typeof PROXY_DLL_OPTIONS[number]["value"];
export const DEFAULT_PROXY_DLL: ProxyDllValue = "dxgi.dll";

export const FSR4_VARIANT_OPTIONS = [
  {
    value: "rdna23-int8",
    label: "Steam Deck / RDNA2-3 优化版",
    hint: "使用内置 FSR4 INT8 4.0.2c，推荐 Steam Deck 与其他非 RDNA4 设备。",
  },
  {
    value: "rdna4-native",
    label: "原生组件 / RDNA4",
    hint: "使用 OptiScaler 0.9.2a 组件内附的 amd_fidelityfx_upscaler_dx12.dll。",
  },
] as const;

export type Fsr4VariantValue = typeof FSR4_VARIANT_OPTIONS[number]["value"];
export const DEFAULT_FSR4_VARIANT: Fsr4VariantValue = "rdna23-int8";

// Common timeout values
export const TIMEOUTS = {
  resultDisplay: 5000,  // 5 seconds
  pathCheck: 3000       // 3 seconds
};

// Message strings
export const MESSAGES = {
  modInstalled: "OptiScaler 模组已安装",
  modNotInstalled: "OptiScaler 模组未安装",
  installing: "正在安装 OptiScaler…",
  installButton: "安装 OptiScaler 模组",
  uninstalling: "正在移除 OptiScaler…",
  uninstallButton: "移除 OptiScaler 模组",
  installSuccess: "OptiScaler 模组安装成功！",
  uninstallSuccess: "OptiScaler 模组已移除。",
  instructionTitle: "使用说明：",
  instructionText: "标准方式请使用“复制启动选项”。如需包装器命令，请开启手动模式以显示“复制修补命令”和“复制撤销修补命令”。\n\n游戏内：在图形设置中启用 DLSS，以在 DirectX 12 游戏中使用 FSR 3.1/XeSS 2.0。\n\n如需更多 OptiScaler 选项，可将一个背键映射为键盘 Insert 键。"
};
