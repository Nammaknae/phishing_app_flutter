import { Router } from "express";
import { AuthController } from "./auth.controller";
import { AuthService } from "./auth.service";

export const authRouter = Router();

// 아주 단순한 형태의 "수동 DI(의존성 주입)".
// 규모가 커지면 컨테이너(tsyringe 등)로 대체할 수 있습니다.
const authController = new AuthController(new AuthService());

// POST /api/auth/signup
authRouter.post("/signup", authController.signup);

// POST /api/auth/login
authRouter.post("/login", authController.login);

// POST /api/auth/oauth
authRouter.post("/oauth", authController.oauth);

