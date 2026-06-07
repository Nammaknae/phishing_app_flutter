import type { Request, Response } from "express";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { env } from "../../config/env";
import { ScansService } from "./scans.service";

type HttpError = Error & { statusCode?: number };

function getStatusCode(err: unknown, fallback = 500) {
  if (err instanceof z.ZodError) {
    return 400;
  }
  if (err && typeof err === "object" && "statusCode" in err) {
    const code = (err as HttpError).statusCode;
    if (typeof code === "number") return code;
  }
  return fallback;
}

function toErrorResponse(err: unknown) {
  if (err instanceof Error) return { message: err.message };
  return { message: "Unknown error" };
}

function getBearerToken(req: Request) {
  const header = req.header("authorization");
  if (!header?.startsWith("Bearer ")) return null;
  return header.slice("Bearer ".length);
}

const scanTextSchema = z.object({
  device_id: z.string().min(1),
  content: z.string().min(1),
  source_app: z.string().min(1).optional(),
  sender: z.string().min(1).optional(),
});

const scanUrlSchema = z.object({
  device_id: z.string().min(1),
  url: z.string().url(),
  source_app: z.string().min(1).optional(),
  sender: z.string().min(1).optional(),
});

const notificationScanSchema = z.object({
  appName: z.string().min(1),
  sender: z.string().min(1),
  message: z.string().min(1),
  device_id: z.string().min(1),
});

export class ScansController {
  constructor(private readonly scansService: ScansService) {}

  // 로그인/비로그인 모두 허용.
  // - Authorization 헤더가 있으면 유저로 처리(토큰이 잘못되면 401)
  // - 없으면 게스트로 처리(device_id 필수, guestLimit 미들웨어가 호출 제한을 담당)
  private getOptionalUserId(req: Request): string | null {
    const token = getBearerToken(req);
    if (!token) return null;

    try {
      const payload = jwt.verify(token, env.JWT_ACCESS_SECRET) as {
        userId?: string;
      };
      if (typeof payload?.userId !== "string" || payload.userId.length === 0) {
        throw new Error("Invalid token");
      }
      return payload.userId;
    } catch {
      const err = new Error("Invalid token");
      (err as any).statusCode = 401;
      throw err;
    }
  }

  postText = async (req: Request, res: Response) => {
    try {
      const input = scanTextSchema.parse(req.body);
      const userId = this.getOptionalUserId(req);

      const result = await this.scansService.scanText({
        input,
        userId,
      });
      return res.status(200).json(result);
    } catch (err) {
      return res.status(getStatusCode(err)).json(toErrorResponse(err));
    }
  };

  postUrl = async (req: Request, res: Response) => {
    try {
      const input = scanUrlSchema.parse(req.body);
      const userId = this.getOptionalUserId(req);

      const result = await this.scansService.scanUrl({
        input,
        userId,
      });
      return res.status(200).json(result);
    } catch (err) {
      return res.status(getStatusCode(err)).json(toErrorResponse(err));
    }
  };

  /** POST /api/scans — 알림 수집 스캔 (requireAuth → req.user.userId) */
  postNotificationScan = async (req: Request, res: Response) => {
    try {
      const userId = req.user?.userId;
      if (!userId) {
        return res.status(401).json({ message: "Unauthorized" });
      }

      const input = notificationScanSchema.parse(req.body);
      const result = await this.scansService.scanFromNotification({
        input,
        userId,
      });

      return res.status(201).json(result);
    } catch (err) {
      if (err instanceof z.ZodError) {
        return res.status(400).json({
          message: "Invalid request body",
          issues: err.issues,
        });
      }
      return res.status(getStatusCode(err)).json(toErrorResponse(err));
    }
  };
}

