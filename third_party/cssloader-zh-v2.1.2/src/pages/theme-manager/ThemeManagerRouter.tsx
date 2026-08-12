import { Tabs } from "decky-frontend-lib";
import { Permissions } from "../../apiTypes";
import { useCssLoaderState } from "../../state";
import { LogInPage } from "./LogInPage";
import { StarredThemesPage } from "./StarredThemesPage";
import { SubmissionsPage } from "./SubmissionBrowserPage";
import { ThemeBrowserPage } from "./ThemeBrowserPage";
import { ThemeBrowserCardStyles } from "../../components/Styles";
export function ThemeManagerRouter() {
  const { apiMeData, currentTab, setGlobalState, browserCardSize } = useCssLoaderState();
  return (
    <div
      style={{
        marginTop: "40px",
        height: "calc(100% - 40px)",
        background: "#0e141b",
      }}
    >
      <ThemeBrowserCardStyles />
      <Tabs
        activeTab={currentTab}
        onShowTab={(tabID: string) => {
          setGlobalState("currentTab", tabID);
        }}
        tabs={[
          {
            title: "全部主题",
            content: <ThemeBrowserPage />,
            id: "ThemeBrowser",
          },
          ...(!!apiMeData
            ? [
                {
                  title: "收藏的主题",
                  content: <StarredThemesPage />,
                  id: "StarredThemes",
                },
                ...(apiMeData.permissions.includes(Permissions.viewSubs)
                  ? [
                      {
                        title: "投稿",
                        content: <SubmissionsPage />,
                        id: "SubmissionsPage",
                      },
                    ]
                  : []),
              ]
            : []),
          {
            title: "DeckThemes 账户",
            content: <LogInPage />,
            id: "LogInPage",
          },
        ]}
      />
    </div>
  );
}
