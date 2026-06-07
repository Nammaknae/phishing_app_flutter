import { prisma } from "../../db/prisma";
import { checkUrlsWithSafeBrowsing } from "../../utils/googleSafeBrowsing";
import {
  checkUrlsWithXgboost,
  type XgboostUrlResult,
  type XgboostVerdict,
} from "../../utils/xgboost";

type ScanTextInput = {
  device_id: string;
  content: string;
  source_app?: string;
  sender?: string;
};

type ScanUrlInput = {
  device_id: string;
  url: string;
  source_app?: string;
  sender?: string;
};

export type NotificationScanInput = {
  appName: string;
  sender: string;
  message: string;
  device_id: string;
};

export type NotificationRiskLevel = "SAFE" | "CAUTION" | "WARNING";

export type NotificationScanResponse = {
  id: string;
  riskLevel: NotificationRiskLevel;
  createdAt: string;
};

function extractUrls(text: string): string[] {
  const regex = /\bhttps?:\/\/[^\s<>"']+/gi;
  return Array.from(text.match(regex) ?? []);
}

function getWorstXgboostVerdict(
  results: XgboostUrlResult[],
): XgboostVerdict | null {
  if (results.length === 0) return null;
  if (results.some((r) => r.verdict === "malicious")) return "malicious";
  if (results.some((r) => r.verdict === "suspicious")) return "suspicious";
  return "safe";
}

function getMaxXgboostScore(results: XgboostUrlResult[]): number | null {
  if (results.length === 0) return null;
  return results.reduce((max, r) => (r.score > max ? r.score : max), 0);
}

function decideFinalGrade(params: {
  isMaliciousBySafeBrowsing: boolean;
  worstXgboostVerdict: XgboostVerdict | null;
}): "SAFE" | "SUSPICIOUS" | "DANGER" {
  if (params.isMaliciousBySafeBrowsing) return "DANGER";

  if (params.worstXgboostVerdict === "malicious") return "DANGER";
  if (params.worstXgboostVerdict === "suspicious") return "SUSPICIOUS";
  return "SAFE";
}

/** Prisma RiskGrade → 프론트엔드 약속 riskLevel */
function toApiRiskLevel(
  grade: "SAFE" | "SUSPICIOUS" | "DANGER",
): NotificationRiskLevel {
  switch (grade) {
    case "DANGER":
      return "WARNING";
    case "SUSPICIOUS":
      return "CAUTION";
    default:
      return "SAFE";
  }
}

export class ScansService {
  async scanText(params: {
    input: ScanTextInput;
    userId?: string | null;
  }) {
    const { input } = params;
    const urls = extractUrls(input.content);
    return this.runPipeline({
      userId: params.userId ?? null,
      deviceId: input.device_id,
      content: input.content,
      sourceApp: input.source_app ?? null,
      sender: input.sender ?? null,
      extractedUrls: urls,
    });
  }

  /**
   * 알림 수집 파이프라인 (POST /api/scans)
   * - 로그인 유저 전용 (userId 필수)
   * - 기존 scanText → runPipeline 재사용
   */
  async scanFromNotification(params: {
    input: NotificationScanInput;
    userId: string;
  }): Promise<NotificationScanResponse> {
    const { input, userId } = params;

    const pipelineResult = await this.scanText({
      input: {
        device_id: input.device_id,
        content: input.message,
        source_app: input.appName,
        sender: input.sender,
      },
      userId,
    });

    const riskLevel = toApiRiskLevel(pipelineResult.final_risk_grade);

    if (riskLevel === "WARNING" || riskLevel === "CAUTION") {
      await prisma.alert.create({
        data: {
          userId: BigInt(userId),
          resultId: BigInt(pipelineResult.result_id),
        },
      });
    }

    const analyzedAt = pipelineResult.analyzed_at;
    const createdAt =
      analyzedAt instanceof Date
        ? analyzedAt.toISOString()
        : new Date(analyzedAt).toISOString();

    return {
      id: pipelineResult.result_id,
      riskLevel,
      createdAt,
    };
  }

  async scanUrl(params: { input: ScanUrlInput; userId?: string | null }) {
    const { input } = params;
    const urls = [input.url];
    return this.runPipeline({
      userId: params.userId ?? null,
      deviceId: input.device_id,
      content: input.url,
      sourceApp: input.source_app ?? null,
      sender: input.sender ?? null,
      extractedUrls: urls,
    });
  }

  private async runPipeline(args: {
    userId: string | null;
    deviceId: string;
    content: string;
    sourceApp: string | null;
    sender: string | null;
    extractedUrls: string[];
  }) {
    await prisma.device.upsert({
      where: { deviceId: args.deviceId },
      create: {
        deviceId: args.deviceId,
        userId: args.userId ? BigInt(args.userId) : null,
      },
      update: {
        userId: args.userId ? BigInt(args.userId) : undefined,
      },
      select: { deviceId: true },
    });

    const log = await prisma.messageLog.create({
      data: {
        userId: args.userId ? BigInt(args.userId) : null,
        deviceId: args.deviceId,
        sourceApp: args.sourceApp,
        sender: args.sender,
        content: args.content,
        hasUrl: args.extractedUrls.length > 0,
      },
      select: { id: true },
    });

    const safeBrowsingResults =
      args.extractedUrls.length > 0
        ? await checkUrlsWithSafeBrowsing(args.extractedUrls)
        : [];

    const isMaliciousBySafeBrowsing = safeBrowsingResults.some(
      (r) => r.isMalicious,
    );

    const xgboostResults =
      !isMaliciousBySafeBrowsing && args.extractedUrls.length > 0
        ? await checkUrlsWithXgboost(args.extractedUrls, {
            sourceApp: args.sourceApp,
            messageText: args.content,
          })
        : [];

    const worstXgboostVerdict = getWorstXgboostVerdict(xgboostResults);
    const xgboostScore = getMaxXgboostScore(xgboostResults);

    const finalRiskGrade = decideFinalGrade({
      isMaliciousBySafeBrowsing,
      worstXgboostVerdict,
    });

    const finalRiskScore = isMaliciousBySafeBrowsing
      ? 100
      : xgboostScore !== null
        ? Math.max(0, Math.min(100, Math.round(xgboostScore * 100)))
        : 0;

    const step1Safebrowsing: "CLEAN" | "MALICIOUS" | null =
      args.extractedUrls.length === 0
        ? null
        : isMaliciousBySafeBrowsing
          ? "MALICIOUS"
          : "CLEAN";

    const detection = await prisma.detectionResult.create({
      data: {
        logId: log.id,
        extractedUrls:
          args.extractedUrls.length > 0 ? JSON.stringify(args.extractedUrls) : null,
        step1Safebrowsing,
        step2XgboostScore: xgboostScore,
        step3KcelectraIntent: null,
        finalRiskScore,
        finalRiskGrade,
        llmResponseGuide: null,
      },
      select: {
        id: true,
        logId: true,
        step1Safebrowsing: true,
        finalRiskScore: true,
        finalRiskGrade: true,
        analyzedAt: true,
      },
    });

    return {
      log_id: log.id.toString(),
      result_id: detection.id.toString(),
      extracted_urls: args.extractedUrls,
      safe_browsing: safeBrowsingResults,
      xgboost: xgboostResults,
      final_risk_grade: detection.finalRiskGrade,
      final_risk_score: detection.finalRiskScore,
      analyzed_at: detection.analyzedAt,
    };
  }
}
