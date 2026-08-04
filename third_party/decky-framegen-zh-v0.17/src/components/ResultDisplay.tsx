import { PanelSectionRow } from "@decky/ui";
import { FC } from "react";
import { STYLES } from "../utils/constants";
import { ApiResponse } from "../types/index";

export type OperationResult = ApiResponse;

interface ResultDisplayProps {
  result: OperationResult | null;
}

export const ResultDisplay: FC<ResultDisplayProps> = ({ result }) => {
  if (!result) return null;

  const isSuccess = result.status === "success";
  
  return (
    <PanelSectionRow>
      <div style={isSuccess ? STYLES.statusInstalled : STYLES.statusNotInstalled}>
        {isSuccess ? (
          <>
            {result.output?.includes("uninstall") || result.output?.includes("remov") 
              ? "OptiScaler 模组已成功移除" 
              : "OptiScaler 模组已成功安装"}
          </>
        ) : (
          <>
            <strong>错误：</strong> {result.message || "操作失败"}
          </>
        )}
        {result.output && !isSuccess && (
          <details style={{ marginTop: '8px' }}>
            <summary style={{ cursor: 'pointer', fontSize: '12px' }}>查看详情</summary>
            <pre style={{ ...STYLES.preWrap, fontSize: '11px', marginTop: '4px' }}>
              {result.output}
            </pre>
          </details>
        )}
      </div>
    </PanelSectionRow>
  );
};
