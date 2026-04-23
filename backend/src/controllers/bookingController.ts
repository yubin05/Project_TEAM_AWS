import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import db from '../models/database';
import { Booking, Room, Hotel } from '../types';
import logger from '../utils/logger';

export function createBooking(req: Request, res: Response): void {
  try {
    const { hotel_id, room_id, check_in_date, check_out_date, guests, special_requests } = req.body;
    const userId = req.user!.userId;

    if (!hotel_id || !room_id || !check_in_date || !check_out_date || !guests) {
      res.status(400).json({ success: false, message: '필수 정보를 모두 입력해주세요.' });
      return;
    }

    const checkIn = new Date(check_in_date);
    const checkOut = new Date(check_out_date);

    if (checkIn >= checkOut) {
      res.status(400).json({ success: false, message: '체크아웃 날짜는 체크인 날짜보다 나중이어야 합니다.' });
      return;
    }

    if (checkIn < new Date()) {
      res.status(400).json({ success: false, message: '체크인 날짜는 오늘 이후여야 합니다.' });
      return;
    }

    const room = db.prepare('SELECT * FROM rooms WHERE id = ? AND hotel_id = ? AND is_available = 1')
      .get(room_id, hotel_id) as Room | undefined;

    if (!room) {
      res.status(404).json({ success: false, message: '객실을 찾을 수 없습니다.' });
      return;
    }

    if (room.capacity < Number(guests)) {
      res.status(400).json({ success: false, message: `해당 객실의 최대 수용 인원은 ${room.capacity}명입니다.` });
      return;
    }

    const conflict = db.prepare(`
      SELECT COUNT(*) as count FROM bookings
      WHERE room_id = ? AND status IN ('confirmed', 'pending')
      AND check_in_date < ? AND check_out_date > ?
    `).get(room_id, check_out_date, check_in_date) as { count: number };

    if (conflict.count > 0) {
      res.status(409).json({ success: false, message: '해당 날짜에 이미 예약이 있습니다.' });
      return;
    }

    const nights = Math.ceil((checkOut.getTime() - checkIn.getTime()) / (1000 * 60 * 60 * 24));
    const discountedPrice = room.price_per_night * (1 - room.discount_rate / 100);
    const totalPrice = discountedPrice * nights;

    const bookingId = uuidv4();
    db.prepare(`
      INSERT INTO bookings (id, user_id, hotel_id, room_id, check_in_date, check_out_date, guests, total_price, status, special_requests)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'confirmed', ?)
    `).run(bookingId, userId, hotel_id, room_id, check_in_date, check_out_date, guests, totalPrice, special_requests || null);

    res.status(201).json({
      success: true,
      message: '예약이 완료되었습니다.',
      data: {
        id: bookingId,
        total_price: totalPrice,
        nights,
        status: 'confirmed'
      }
    });
  } catch (error) {
    logger.error('Create booking error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function getUserBookings(req: Request, res: Response): void {
  try {
    const userId = req.user!.userId;
    const { status, page = 1, limit = 10 } = req.query;

    let query = `
      SELECT b.*, h.name as hotel_name, h.address as hotel_address, h.images as hotel_images,
             r.name as room_name, r.images as room_images, r.type as room_type
      FROM bookings b
      JOIN hotels h ON b.hotel_id = h.id
      JOIN rooms r ON b.room_id = r.id
      WHERE b.user_id = ?
    `;
    const params: (string | number)[] = [userId];

    if (status) {
      query += ` AND b.status = ?`;
      params.push(status as string);
    }

    query += ` ORDER BY b.created_at DESC LIMIT ? OFFSET ?`;
    params.push(Number(limit), (Number(page) - 1) * Number(limit));

    const bookings = db.prepare(query).all(...params) as (Booking & {
      hotel_name: string; hotel_images: string; room_name: string; room_images: string; room_type: string;
    })[];

    const total = (db.prepare(`SELECT COUNT(*) as count FROM bookings WHERE user_id = ? ${status ? `AND status = '${status}'` : ''}`)
      .get(userId) as { count: number }).count;

    res.json({
      success: true,
      data: {
        bookings: bookings.map(b => ({
          ...b,
          hotel_images: JSON.parse(b.hotel_images || '[]'),
          room_images: JSON.parse(b.room_images || '[]')
        })),
        pagination: { total, page: Number(page), limit: Number(limit), total_pages: Math.ceil(total / Number(limit)) }
      }
    });
  } catch (error) {
    logger.error('Get bookings error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function getBookingById(req: Request, res: Response): void {
  try {
    const { id } = req.params;
    const userId = req.user!.userId;

    const booking = db.prepare(`
      SELECT b.*, h.name as hotel_name, h.address as hotel_address, h.images as hotel_images,
             h.check_in_time, h.check_out_time, h.city, h.region,
             r.name as room_name, r.images as room_images, r.type as room_type, r.capacity
      FROM bookings b
      JOIN hotels h ON b.hotel_id = h.id
      JOIN rooms r ON b.room_id = r.id
      WHERE b.id = ? AND b.user_id = ?
    `).get(id, userId) as (Booking & {
      hotel_name: string; hotel_address: string; hotel_images: string;
      check_in_time: string; check_out_time: string; city: string; region: string;
      room_name: string; room_images: string; room_type: string; capacity: number;
    }) | undefined;

    if (!booking) {
      res.status(404).json({ success: false, message: '예약을 찾을 수 없습니다.' });
      return;
    }

    res.json({
      success: true,
      data: {
        ...booking,
        hotel_images: JSON.parse(booking.hotel_images || '[]'),
        room_images: JSON.parse(booking.room_images || '[]')
      }
    });
  } catch (error) {
    logger.error('Get booking error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function cancelBooking(req: Request, res: Response): void {
  try {
    const { id } = req.params;
    const userId = req.user!.userId;

    const booking = db.prepare('SELECT * FROM bookings WHERE id = ? AND user_id = ?').get(id, userId) as Booking | undefined;

    if (!booking) {
      res.status(404).json({ success: false, message: '예약을 찾을 수 없습니다.' });
      return;
    }

    if (booking.status === 'cancelled') {
      res.status(400).json({ success: false, message: '이미 취소된 예약입니다.' });
      return;
    }

    if (booking.status === 'completed') {
      res.status(400).json({ success: false, message: '완료된 예약은 취소할 수 없습니다.' });
      return;
    }

    const checkIn = new Date(booking.check_in_date);
    const now = new Date();
    const hoursUntilCheckIn = (checkIn.getTime() - now.getTime()) / (1000 * 60 * 60);

    if (hoursUntilCheckIn < 24) {
      res.status(400).json({ success: false, message: '체크인 24시간 전에는 취소할 수 없습니다.' });
      return;
    }

    db.prepare('UPDATE bookings SET status = \'cancelled\', updated_at = datetime(\'now\') WHERE id = ?').run(id);

    res.json({ success: true, message: '예약이 취소되었습니다.' });
  } catch (error) {
    logger.error('Cancel booking error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export function getHostBookings(req: Request, res: Response): void {
  try {
    const hostId = req.user!.userId;
    const { status, page = 1, limit = 20 } = req.query;

    let query = `
      SELECT b.*, h.name as hotel_name, r.name as room_name,
             u.name as guest_name, u.email as guest_email, u.phone as guest_phone
      FROM bookings b
      JOIN hotels h ON b.hotel_id = h.id AND h.host_id = ?
      JOIN rooms r ON b.room_id = r.id
      JOIN users u ON b.user_id = u.id
      WHERE 1=1
    `;
    const params: (string | number)[] = [hostId];

    if (status) {
      query += ` AND b.status = ?`;
      params.push(status as string);
    }

    query += ` ORDER BY b.created_at DESC LIMIT ? OFFSET ?`;
    params.push(Number(limit), (Number(page) - 1) * Number(limit));

    const bookings = db.prepare(query).all(...params);
    res.json({ success: true, data: bookings });
  } catch (error) {
    logger.error('Get host bookings error', { error });
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}
