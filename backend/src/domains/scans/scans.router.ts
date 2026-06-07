import { Router } from "express";
import { requireAuth } from "../../middlewares/auth";
import { guestLimit } from "../../middlewares/guestLimit";
import { ScansController } from "./scans.controller";
import { ScansService } from "./scans.service";

export const scansRouter = Router();

const scansController = new ScansController(new ScansService());

// 게스트(비로그인)일 때만 호출 제한을 적용합니다.
// - Authorization 헤더가 있으면 로그인 플로우로 간주하고 guestLimit를 스킵합니다.
function guestLimitIfGuest(req: any, res: any, next: any) {
  const header = req.header?.("authorization");
  if (header?.startsWith("Bearer ")) return next();
  return guestLimit(req, res, next);
}

// POST /api/scans — 알림 수집 스캔 (JWT 필수)
scansRouter.post("/", requireAuth, scansController.postNotificationScan);

// POST /api/scans/text
scansRouter.post("/text", guestLimitIfGuest, scansController.postText);

// POST /api/scans/url
scansRouter.post("/url", guestLimitIfGuest, scansController.postUrl);

// GET /api/scans/me
scansRouter.get("/me", (_req, res) => {
  res.status(501).json({ message: "Not implemented" });
});

