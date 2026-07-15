export const AUTHOR_NOTICE = "闲鱼双叶汉化制作，请支持汉化者";

export type TranslationEntry = {
  plugin: string;
  chineseName: string;
  strings: Record<string, string>;
};

// Keep every plugin's wording isolated so updates can be reviewed and released in small batches.
export const TRANSLATIONS: TranslationEntry[] = [
  {
    plugin: "CSS Loader",
    chineseName: "CSS Loader（主题与界面美化）",
    strings: {
      "Themes": "主题",
      "Theme Loader": "主题加载器",
      "Settings": "设置"
    }
  },
  {
    plugin: "vibrantDeck",
    chineseName: "vibrantDeck（屏幕色彩）",
    strings: {
      "Saturation": "饱和度",
      "Display Settings": "屏幕设置",
      "Settings": "设置"
    }
  },
  {
    plugin: "Animation Changer",
    chineseName: "Animation Changer（开机与休眠动画）",
    strings: {
      "Boot Animation": "开机动画",
      "Suspend Animation": "休眠动画",
      "Settings": "设置"
    }
  },
  {
    plugin: "Audio Loader",
    chineseName: "Audio Loader（系统音效）",
    strings: {
      "Audio": "音效",
      "Sound Pack": "音效包",
      "Settings": "设置"
    }
  },
  {
    plugin: "SteamGridDB",
    chineseName: "SteamGridDB（游戏封面）",
    strings: {
      "Change Artwork": "更换封面",
      "Search": "搜索",
      "Settings": "设置"
    }
  },
  {
    plugin: "PowerTools",
    chineseName: "PowerTools（性能调校）",
    strings: {
      "CPU": "CPU",
      "GPU": "GPU",
      "Settings": "设置"
    }
  },
  {
    plugin: "Storage Cleaner",
    chineseName: "Storage Cleaner（缓存清理）",
    strings: {
      "Shader Cache": "着色器缓存",
      "Compatibility Data": "兼容数据",
      "Clean": "清理"
    }
  },
  {
    plugin: "Bluetooth",
    chineseName: "Bluetooth（蓝牙设备）",
    strings: {
      "Paired Devices": "已配对设备",
      "Connect": "连接",
      "Disconnect": "断开连接"
    }
  },
  {
    plugin: "ProtonDB Badges",
    chineseName: "ProtonDB Badges（兼容性标记）",
    strings: { "Rating": "评级", "Reports": "报告", "Settings": "设置" }
  },
  {
    plugin: "Deck Settings",
    chineseName: "Deck Settings（游戏设置推荐）",
    strings: { "Game Settings": "游戏设置", "Search": "搜索", "Settings": "设置" }
  },
  {
    plugin: "HLTB for Deck",
    chineseName: "HLTB for Deck（通关时长）",
    strings: { "HowLongToBeat": "通关时长", "Main Story": "主线流程", "Search": "搜索" }
  },
  {
    plugin: "PlayCount",
    chineseName: "PlayCount（在线人数）",
    strings: { "Players": "玩家人数", "Online": "在线", "Refresh": "刷新" }
  },
  {
    plugin: "TabMaster",
    chineseName: "TabMaster（库标签管理）",
    strings: { "Tabs": "标签页", "Library": "游戏库", "Settings": "设置" }
  },
  {
    plugin: "Game Theme Music",
    chineseName: "Game Theme Music（主题音乐）",
    strings: { "Theme Music": "主题音乐", "Enable": "启用", "Volume": "音量" }
  },
  {
    plugin: "Wine Cellar",
    chineseName: "Wine Cellar（Wine 管理）",
    strings: { "Versions": "版本", "Install": "安装", "Remove": "移除" }
  },
  {
    plugin: "Pause Games",
    chineseName: "Pause Games（暂停游戏）",
    strings: { "Pause": "暂停", "Resume": "继续", "Settings": "设置" }
  },
  {
    plugin: "Controller Tools",
    chineseName: "Controller Tools（控制器工具）",
    strings: { "Controller": "控制器", "Configure": "配置", "Settings": "设置" }
  },
  {
    plugin: "Volume Mixer",
    chineseName: "Volume Mixer（音量混音）",
    strings: { "Applications": "应用程序", "Mute": "静音", "Volume": "音量" }
  },
  {
    plugin: "Battery Tracker",
    chineseName: "Battery Tracker（电池记录）",
    strings: { "Battery": "电池", "History": "历史记录", "Clear": "清除" }
  },
  {
    plugin: "PlayTime",
    chineseName: "PlayTime（游戏时间）",
    strings: { "Play Time": "游戏时间", "Today": "今天", "Total": "总计" }
  },
  {
    plugin: "Free Loader",
    chineseName: "Free Loader（插件加载）",
    strings: { "Plugins": "插件", "Reload": "重新加载", "Settings": "设置" }
  },
  {
    plugin: "DeckMTP",
    chineseName: "DeckMTP（文件互传）",
    strings: { "Connected": "已连接", "Transfer": "传输", "Settings": "设置" }
  },
  {
    plugin: "MangoPeel",
    chineseName: "MangoPeel（性能监控）",
    strings: { "Performance": "性能", "Overlay": "浮层", "Settings": "设置" }
  },
  {
    plugin: "SimpleDeckyTDP",
    chineseName: "SimpleDeckyTDP（TDP 性能控制）",
    strings: { "TDP": "功耗墙", "Performance": "性能", "Apply": "应用" }
  },
  {
    plugin: "Unifideck",
    chineseName: "Unifideck（多平台游戏库）",
    strings: { "Libraries": "游戏库", "Refresh": "刷新", "Settings": "设置" }
  },
  {
    plugin: "LSFG-VK",
    chineseName: "LSFG-VK（小黄鸭帧生成）",
    strings: { "Frame Generation": "帧生成", "Enable": "启用", "Settings": "设置" }
  },
  {
    plugin: "Decky-Framegen",
    chineseName: "Decky-Framegen（FSR4 帧生成）",
    strings: { "Frame Generation": "帧生成", "Enable": "启用", "Settings": "设置" }
  },
  {
    plugin: "CheatDeck",
    chineseName: "CheatDeck（游戏辅助）",
    strings: { "Cheats": "辅助功能", "Enable": "启用", "Settings": "设置" }
  }
];

export const EXACT_TRANSLATIONS = new Map<string, string>(
  TRANSLATIONS.flatMap((entry) => [
    [entry.plugin, entry.chineseName],
    ...Object.entries(entry.strings)
  ])
);
