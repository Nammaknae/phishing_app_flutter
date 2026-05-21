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

// 카카오 간편로그인 추가
authRouter.get("/kakao", (req, res) => {
  
  const KAKAO_CLIENT_ID = "YOUR_KAKAO_CLIENT_ID"; 
  const KAKAO_REDIRECT_URI = "https://smishingteam012.duckdns.org/api/auth/kakao/callback"; 
  const kakaoUrl = `https://kauth.kakao.com/oauth/authorize?client_id=${KAKAO_CLIENT_ID}&redirect_uri=${KAKAO_REDIRECT_URI}&response_type=code`;
  
  res.redirect(kakaoUrl);
});

// 네이버 간편로그인 추가
authRouter.get("/naver", (req, res) => {
  
  const NAVER_CLIENT_ID = "YOUR_NAVER_CLIENT_ID";
  const NAVER_REDIRECT_URI = "https://smishingteam012.duckdns.org/api/auth/naver/callback"; 
  const state = Math.random().toString(36).substring(3, 14); // 보안용 랜덤 문자열
  const naverUrl = `https://nid.naver.com/oauth2.0/authorize?response_type=code&client_id=${NAVER_CLIENT_ID}&redirect_uri=${NAVER_REDIRECT_URI}&state=${state}`;
  
  res.redirect(naverUrl);
});

//  구글 간편로그인
authRouter.get("/google", (req, res) => {
  
  const GOOGLE_CLIENT_ID = "YOUR_GOOGLE_CLIENT_ID";
  const GOOGLE_REDIRECT_URI = "https://smishingteam012.duckdns.org/api/auth/google/callback";

  const params = new URLSearchParams({
    client_id: GOOGLE_CLIENT_ID,
    redirect_uri: GOOGLE_REDIRECT_URI,
    response_type: "code",
    scope: "email profile",
    prompt: "select_account" 
  });

  const googleUrl = `https://accounts.google.com/o/oauth2/v2/auth?${params.toString()}`;
  res.redirect(googleUrl);
});

//  구글 로그인 성공 후 구글이 정보를 던져주는 곳
authRouter.get("/google/callback", async (req, res) => {
  const { code } = req.query; 
  
  if (!code) {
    return res.status(400).send("인증 코드가 없습니다.");
  }

  res.send(`구글 로그인 성공! 인증 코드: ${code}`); 
});
