import { staticClasses } from "@decky/ui";
import { definePlugin } from "@decky/api";
import { GiPlasticDuck } from "react-icons/gi";
import { Content } from "./components/Content";

export default definePlugin(() => {
  console.log("decky-lsfg-vk plugin initializing");

  return {
    name: "小黄鸭",
    titleView: <div className={staticClasses.Title}>小黄鸭</div>,
    alwaysRender: true,
    content: <Content />,
    icon: <GiPlasticDuck />,
    onDismount() {
      console.log("decky-lsfg-vk unloading");
    }
  };
});
