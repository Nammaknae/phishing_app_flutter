import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import { z } from "zod";
import { Prisma } from "@prisma/client";
import { prisma } from "../../db/prisma";
import { env } from "../../config/env";

// AuthService는 인증/가입 관련 "비즈니스 로직"만 담당합니다.
// - HTTP(req/res) 처리는 controller에서 수행
// - DB 처리는 Prisma를 통해 수행
// - 입력 검증은 zod로 1차 방어(잘못된 요청은 빠르게 실패)
const signupInputSchema = z.object({
  email: z.string().email(),
  password: z.string().min(6),
});

const loginInputSchema = z.object({
  email: z.string().email(),
  password: z.string().min(1),
});

const oauthInputSchema = z.object({
  provider: z.enum(["KAKAO", "NAVER", "GOOGLE"]),
  provider_id: z.string().min(1),
});

export type SignupInput = z.infer<typeof signupInputSchema>;
export type LoginInput = z.infer<typeof loginInputSchema>;
export type OauthInput = z.infer<typeof oauthInputSchema>;

export type AuthTokenPayload = {
  userId: string;
  role: "USER" | "ADMIN";
};

function signAccessToken(payload: AuthTokenPayload) {
  const expiresIn = env.JWT_ACCESS_EXPIRES_IN as jwt.SignOptions["expiresIn"];
  // access token에는 최소한의 정보(userId, role)만 넣습니다.
  return jwt.sign(payload, env.JWT_ACCESS_SECRET, {
    expiresIn,
  });
}

export class AuthService {
  async signup(raw: SignupInput) {
    const input = signupInputSchema.parse(raw);

    // 비밀번호는 절대 평문 저장 금지: bcrypt 해시로만 저장
    const passwordHash = await bcrypt.hash(input.password, 10);

    // users(공통) + user_local_auth(이메일 인증) 를 트랜잭션으로 묶어서
    // 중간 실패 시 "유저만 생성되고 auth가 없는" 상태를 방지합니다.
    let user: { id: bigint; role: "USER" | "ADMIN" };
    try {
      user = await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
        const createdUser = await tx.user.create({
          data: { role: "USER" },
          select: { id: true, role: true },
        });

        await tx.userLocalAuth.create({
          data: {
            userId: createdUser.id,
            email: input.email,
            passwordHash,
          },
          select: { userId: true },
        });

        return createdUser;
      });
    } catch (err) {
      if (
        err instanceof Prisma.PrismaClientKnownRequestError &&
        err.code === "P2002"
      ) {
        const duplicate = new Error("Email already registered");
        (duplicate as any).statusCode = 409;
        throw duplicate;
      }
      throw err;
    }

    const token = signAccessToken({
      userId: user.id.toString(),
      role: user.role,
    });

    return {
      user: { id: user.id.toString(), role: user.role, email: input.email },
      accessToken: token,
    };
  }

  async login(raw: LoginInput) {
    const input = loginInputSchema.parse(raw);

    // 이메일로 로컬 계정을 찾고, 연결된 users row에서 role/id를 함께 가져옵니다.
    const local = await prisma.userLocalAuth.findUnique({
      where: { email: input.email },
      include: { user: { select: { id: true, role: true } } },
    });

    if (!local) {
      const err = new Error("Invalid email or password");
      (err as any).statusCode = 401;
      throw err;
    }

    const ok = await bcrypt.compare(input.password, local.passwordHash);
    if (!ok) {
      const err = new Error("Invalid email or password");
      (err as any).statusCode = 401;
      throw err;
    }

    const token = signAccessToken({
      userId: local.user.id.toString(),
      role: local.user.role,
    });

    return {
      user: {
        id: local.user.id.toString(),
        role: local.user.role,
        email: local.email,
      },
      accessToken: token,
    };
  }

  async oauth(raw: OauthInput) {
    const input = oauthInputSchema.parse(raw);

    // provider + provider_id 조합은 유니크 키(스키마에 @@unique)로 보장됩니다.
    // 이미 존재하면 "로그인", 없으면 "가입 후 로그인"으로 처리합니다.
    const existing = await prisma.userSocialAuth.findFirst({
      where: { provider: input.provider, providerId: input.provider_id },
      include: { user: { select: { id: true, role: true } } },
    });

    if (existing) {
      const token = signAccessToken({
        userId: existing.user.id.toString(),
        role: existing.user.role,
      });
      return {
        user: { id: existing.user.id.toString(), role: existing.user.role },
        accessToken: token,
        isNew: false,
      };
    }

    // 신규 소셜 계정: users 생성 + user_social_auth 연결을 트랜잭션으로 처리
    const user = await prisma.$transaction(async (tx: Prisma.TransactionClient) => {
      const createdUser = await tx.user.create({
        data: { role: "USER" },
        select: { id: true, role: true },
      });
      await tx.userSocialAuth.create({
        data: {
          userId: createdUser.id,
          provider: input.provider,
          providerId: input.provider_id,
        },
        select: { id: true },
      });
      return createdUser;
    });

    const token = signAccessToken({
      userId: user.id.toString(),
      role: user.role,
    });

    return {
      user: { id: user.id.toString(), role: user.role },
      accessToken: token,
      isNew: true,
    };
  }
}

