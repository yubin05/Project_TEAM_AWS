import { Request, Response, NextFunction } from 'express';
import jwt from 'jsonwebtoken';
import { config, isLocal } from '../config';
import { JwtPayload } from '../types';

declare global {
  namespace Express {
    interface Request { user?: JwtPayload; }
  }
}

// AWS 모드에서만 CognitoJwtVerifier를 로드 (로컬 빌드 시 패키지 없어도 동작)
let cognitoVerifier: any = null;
if (!isLocal && config.cognito.userPoolId) {
  try {
    const { CognitoJwtVerifier } = require('aws-jwt-verify');
    cognitoVerifier = CognitoJwtVerifier.create({
      userPoolId: config.cognito.userPoolId,
      tokenUse:   'access',
      clientId:   config.cognito.clientId,
    });
  } catch {
    console.warn('⚠️  aws-jwt-verify 로드 실패 — Cognito 검증 비활성화');
  }
}

// ─── 토큰 검증 미들웨어 ────────────────────────────────────────────────────────

export async function authenticateToken(
  req: Request, res: Response, next: NextFunction
): Promise<void> {
  const token = req.headers['authorization']?.split(' ')[1];

  if (!token) {
    res.status(401).json({ success: false, message: '인증 토큰이 필요합니다.' });
    return;
  }

  try {
    if (isLocal) {
      // ── 로컬 모드: 자체 JWT 검증 ──────────────────────────────────────────
      const decoded = jwt.verify(token, config.jwt.secret) as JwtPayload;
      req.user = decoded;
    } else {
      // ── AWS 모드: Cognito Access Token 검증 ───────────────────────────────
      if (!cognitoVerifier) throw new Error('Cognito verifier not initialized');
      const payload = await cognitoVerifier.verify(token);
      req.user = {
        userId: payload.sub,
        email:  payload.email ?? '',
        role:   payload['custom:role'] ?? 'user',
      };
    }
    next();
  } catch {
    res.status(403).json({ success: false, message: '유효하지 않은 토큰입니다.' });
  }
}

// ─── 역할 검사 미들웨어 ────────────────────────────────────────────────────────

export function requireRole(...roles: string[]) {
  return (req: Request, res: Response, next: NextFunction): void => {
    if (!req.user) {
      res.status(401).json({ success: false, message: '인증이 필요합니다.' });
      return;
    }
    if (!roles.includes(req.user.role)) {
      res.status(403).json({ success: false, message: '권한이 없습니다.' });
      return;
    }
    next();
  };
}

// ─── 로컬 전용: JWT 생성 (AWS 모드에서는 Cognito가 발급) ──────────────────────

export function generateToken(payload: JwtPayload): string {
  if (!isLocal) {
    throw new Error('generateToken은 로컬 모드 전용입니다. AWS 모드에서는 Cognito를 사용하세요.');
  }
  return jwt.sign(payload, config.jwt.secret, { expiresIn: '7d' });
}
