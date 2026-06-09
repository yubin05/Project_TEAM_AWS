import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import {
  CognitoIdentityProviderClient,
  InitiateAuthCommand,
  SignUpCommand,
  AdminConfirmSignUpCommand,
  ChangePasswordCommand,
} from '@aws-sdk/client-cognito-identity-provider';
import { RowDataPacket } from 'mysql2';
import pool from '../models/pool';
import { User } from '../types';
import logger from '../utils/logger';
import { config } from '../config';

const cognito = new CognitoIdentityProviderClient({ region: config.cognito.region });

export async function register(req: Request, res: Response): Promise<void> {
  try {
    const { email, password, name, phone, role = 'user' } = req.body;

    if (!email || !password || !name) {
      res.status(400).json({ success: false, message: '이메일, 비밀번호, 이름은 필수입니다.' });
      return;
    }
    if (password.length < 8) {
      res.status(400).json({ success: false, message: '비밀번호는 8자 이상이어야 합니다.' });
      return;
    }

    const userRole = role === 'host' ? 'host' : 'user';

    const signUpResult = await cognito.send(new SignUpCommand({
      ClientId: config.cognito.clientId,
      Username: email,
      Password: password,
      UserAttributes: [
        { Name: 'email',       Value: email },
        { Name: 'name',        Value: name },
        { Name: 'custom:role', Value: userRole },
      ],
    }));

    const cognitoSub = signUpResult.UserSub!;

    await cognito.send(new AdminConfirmSignUpCommand({
      UserPoolId: config.cognito.userPoolId,
      Username:   email,
    }));

    await pool.query(
      'INSERT INTO users (id, email, password, name, phone, role) VALUES (?, ?, ?, ?, ?, ?)',
      [cognitoSub, email, uuidv4(), name, phone || null, userRole]
    );

    const authResult = await cognito.send(new InitiateAuthCommand({
      AuthFlow: 'USER_PASSWORD_AUTH',
      ClientId: config.cognito.clientId,
      AuthParameters: { USERNAME: email, PASSWORD: password },
    }));

    res.status(201).json({
      success: true,
      message: '회원가입이 완료되었습니다.',
      data: {
        token: authResult.AuthenticationResult?.AccessToken,
        user: { id: cognitoSub, email, name, role: userRole },
      },
    });
  } catch (error: any) {
    if (error.name === 'UsernameExistsException') {
      res.status(409).json({ success: false, message: '이미 사용 중인 이메일입니다.' });
      return;
    }
    if (error.name === 'InvalidPasswordException') {
      res.status(400).json({ success: false, message: '비밀번호가 정책을 만족하지 않습니다.' });
      return;
    }
    logger.error('Register error', { error: error.message });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function login(req: Request, res: Response): Promise<void> {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      res.status(400).json({ success: false, message: '이메일과 비밀번호를 입력해주세요.' });
      return;
    }

    const result = await cognito.send(new InitiateAuthCommand({
      AuthFlow: 'USER_PASSWORD_AUTH',
      ClientId: config.cognito.clientId,
      AuthParameters: {
        USERNAME: email,
        PASSWORD: password,
      },
    }));

    const accessToken = result.AuthenticationResult?.AccessToken;
    if (!accessToken) {
      res.status(401).json({ success: false, message: '로그인에 실패했습니다.' });
      return;
    }

    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT id, email, name, role, profile_image FROM users WHERE email = ?',
      [email]
    );
    const user = (rows as RowDataPacket[])[0] as User | undefined;
    if (!user) {
      res.status(401).json({ success: false, message: '사용자 정보를 찾을 수 없습니다.' });
      return;
    }

    res.json({
      success: true,
      message: '로그인 성공',
      data: {
        token: accessToken,
        user: { id: user.id, email: user.email, name: user.name, role: user.role, profile_image: user.profile_image },
      },
    });
  } catch (error: any) {
    if (error.name === 'NotAuthorizedException' || error.name === 'UserNotFoundException') {
      res.status(401).json({ success: false, message: '이메일 또는 비밀번호가 잘못되었습니다.' });
      return;
    }
    logger.error('Login error', { error: error.message });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getProfile(req: Request, res: Response): Promise<void> {
  try {
    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT id, email, name, phone, profile_image, role, created_at FROM users WHERE id = ?',
      [req.user!.userId]
    );
    const user = (rows as RowDataPacket[])[0];
    if (!user) {
      res.status(404).json({ success: false, message: '사용자를 찾을 수 없습니다.' });
      return;
    }
    res.json({ success: true, data: user });
  } catch (error) {
    logger.error('Get profile error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function updateProfile(req: Request, res: Response): Promise<void> {
  try {
    const { name, phone } = req.body;
    await pool.query(
      'UPDATE users SET name = ?, phone = ? WHERE id = ?',
      [name, phone, req.user!.userId]
    );
    res.json({ success: true, message: '프로필이 업데이트되었습니다.' });
  } catch (error) {
    logger.error('Update profile error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function changePassword(req: Request, res: Response): Promise<void> {
  try {
    const { current_password, new_password } = req.body;

    if (new_password.length < 8) {
      res.status(400).json({ success: false, message: '새 비밀번호는 8자 이상이어야 합니다.' });
      return;
    }

    const accessToken = req.headers['authorization']?.split(' ')[1];
    await cognito.send(new ChangePasswordCommand({
      AccessToken:      accessToken,
      PreviousPassword: current_password,
      ProposedPassword: new_password,
    }));

    res.json({ success: true, message: '비밀번호가 변경되었습니다.' });
  } catch (error: any) {
    if (error.name === 'NotAuthorizedException') {
      res.status(401).json({ success: false, message: '현재 비밀번호가 잘못되었습니다.' });
      return;
    }
    if (error.name === 'InvalidPasswordException') {
      res.status(400).json({ success: false, message: '새 비밀번호는 8자 이상이며 대문자, 소문자, 숫자, 특수문자를 모두 포함해야 합니다.' });
      return;
    }
    logger.error('Change password error', { error: error.message });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getInternalUser(req: Request, res: Response): Promise<void> {
  try {
    const { id } = req.params;
    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT id, email, name, profile_image, role FROM users WHERE id = ?', [id]
    );
    const user = (rows as RowDataPacket[])[0];
    if (!user) {
      res.status(404).json({ success: false, message: '사용자를 찾을 수 없습니다.' });
      return;
    }
    res.json({ success: true, data: user });
  } catch (error) {
    logger.error('Get internal user error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}
