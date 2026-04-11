import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { RowDataPacket } from 'mysql2';
import pool from '../models/pool';
import { Booking, Room } from '../types';

export async function createBooking(req: Request, res: Response): Promise<void> {
  try {
    const { hotel_id, room_id, check_in_date, check_out_date, guests, special_requests } = req.body;
    const userId = req.user!.userId;

    if (!hotel_id || !room_id || !check_in_date || !check_out_date || !guests) {
      res.status(400).json({ success: false, message: '필수 정보를 모두 입력해주세요.' });
      return;
    }

    const checkIn  = new Date(check_in_date);
    const checkOut = new Date(check_out_date);

    if (checkIn >= checkOut) {
      res.status(400).json({ success: false, message: '체크아웃 날짜는 체크인 날짜보다 나중이어야 합니다.' });
      return;
    }
    if (checkIn < new Date()) {
      res.status(400).json({ success: false, message: '체크인 날짜는 오늘 이후여야 합니다.' });
      return;
    }

    const [roomRows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM rooms WHERE id = ? AND hotel_id = ? AND is_available = 1',
      [room_id, hotel_id]
    );
    const room = (roomRows as RowDataPacket[])[0] as Room | undefined;
    if (!room) {
      res.status(404).json({ success: false, message: '객실을 찾을 수 없습니다.' });
      return;
    }
    if (room.capacity < Number(guests)) {
      res.status(400).json({ success: false, message: `해당 객실의 최대 수용 인원은 ${room.capacity}명입니다.` });
      return;
    }

    const [conflictRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as count FROM bookings
       WHERE room_id = ? AND status IN ('confirmed','pending')
       AND check_in_date < ? AND check_out_date > ?`,
      [room_id, check_out_date, check_in_date]
    );
    if (((conflictRows as RowDataPacket[])[0] as { count: number }).count > 0) {
      res.status(409).json({ success: false, message: '해당 날짜에 이미 예약이 있습니다.' });
      return;
    }

    const nights       = Math.ceil((checkOut.getTime() - checkIn.getTime()) / (1000 * 60 * 60 * 24));
    const discounted   = Number(room.price_per_night) * (1 - Number(room.discount_rate) / 100);
    const totalPrice   = discounted * nights;
    const bookingId    = uuidv4();

    await pool.query(
      `INSERT INTO bookings (id, user_id, hotel_id, room_id, check_in_date, check_out_date, guests, total_price, status, special_requests)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'confirmed', ?)`,
      [bookingId, userId, hotel_id, room_id, check_in_date, check_out_date, guests, totalPrice, special_requests ?? null]
    );

    res.status(201).json({
      success: true,
      message: '예약이 완료되었습니다.',
      data: { id: bookingId, total_price: totalPrice, nights, status: 'confirmed' },
    });
  } catch (error) {
    console.error('Create booking error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getUserBookings(req: Request, res: Response): Promise<void> {
  try {
    const userId = req.user!.userId;
    const { status, page = 1, limit = 10 } = req.query;

    let query = `
      SELECT b.*, h.name as hotel_name, h.address as hotel_address, h.images as hotel_images,
             r.name as room_name, r.images as room_images, r.type as room_type
      FROM bookings b
      JOIN hotels h ON b.hotel_id = h.id
      JOIN rooms r  ON b.room_id  = r.id
      WHERE b.user_id = ?
    `;
    const params: (string | number)[] = [userId];

    if (status) { query += ` AND b.status = ?`; params.push(status as string); }
    query += ` ORDER BY b.created_at DESC LIMIT ? OFFSET ?`;
    params.push(Number(limit), (Number(page) - 1) * Number(limit));

    const [rows] = await pool.query<RowDataPacket[]>(query, params);

    const countParams: (string | number)[] = [userId];
    if (status) countParams.push(String(status));
    const [countRows] = await pool.query<RowDataPacket[]>(
      `SELECT COUNT(*) as count FROM bookings WHERE user_id = ? ${status ? `AND status = ?` : ''}`,
      countParams
    );
    const total = ((countRows as RowDataPacket[])[0] as { count: number }).count;

    res.json({
      success: true,
      data: {
        bookings: (rows as RowDataPacket[]).map((b: any) => ({
          ...b,
          hotel_images: typeof b.hotel_images === 'string' ? JSON.parse(b.hotel_images) : (b.hotel_images ?? []),
          room_images:  typeof b.room_images  === 'string' ? JSON.parse(b.room_images)  : (b.room_images  ?? []),
        })),
        pagination: { total, page: Number(page), limit: Number(limit), total_pages: Math.ceil(total / Number(limit)) },
      },
    });
  } catch (error) {
    console.error('Get bookings error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getBookingById(req: Request, res: Response): Promise<void> {
  try {
    const { id } = req.params;
    const userId = req.user!.userId;

    const [rows] = await pool.query<RowDataPacket[]>(`
      SELECT b.*, h.name as hotel_name, h.address as hotel_address, h.images as hotel_images,
             h.check_in_time, h.check_out_time, h.city, h.region,
             r.name as room_name, r.images as room_images, r.type as room_type, r.capacity
      FROM bookings b
      JOIN hotels h ON b.hotel_id = h.id
      JOIN rooms r  ON b.room_id  = r.id
      WHERE b.id = ? AND b.user_id = ?
    `, [id, userId]);

    const booking = (rows as RowDataPacket[])[0];
    if (!booking) {
      res.status(404).json({ success: false, message: '예약을 찾을 수 없습니다.' });
      return;
    }

    res.json({
      success: true,
      data: {
        ...booking,
        hotel_images: typeof booking.hotel_images === 'string' ? JSON.parse(booking.hotel_images) : (booking.hotel_images ?? []),
        room_images:  typeof booking.room_images  === 'string' ? JSON.parse(booking.room_images)  : (booking.room_images  ?? []),
      },
    });
  } catch (error) {
    console.error('Get booking error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function cancelBooking(req: Request, res: Response): Promise<void> {
  try {
    const { id } = req.params;
    const userId = req.user!.userId;

    const [rows] = await pool.query<RowDataPacket[]>(
      'SELECT * FROM bookings WHERE id = ? AND user_id = ?', [id, userId]
    );
    const booking = (rows as RowDataPacket[])[0] as Booking | undefined;
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

    const hoursUntilCheckIn = (new Date(booking.check_in_date).getTime() - Date.now()) / (1000 * 60 * 60);
    if (hoursUntilCheckIn < 24) {
      res.status(400).json({ success: false, message: '체크인 24시간 전에는 취소할 수 없습니다.' });
      return;
    }

    await pool.query(`UPDATE bookings SET status = 'cancelled' WHERE id = ?`, [id]);
    res.json({ success: true, message: '예약이 취소되었습니다.' });
  } catch (error) {
    console.error('Cancel booking error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getHostBookings(req: Request, res: Response): Promise<void> {
  try {
    const hostId = req.user!.userId;
    const { status, page = 1, limit = 20 } = req.query;

    let query = `
      SELECT b.*, h.name as hotel_name, r.name as room_name,
             u.name as guest_name, u.email as guest_email, u.phone as guest_phone
      FROM bookings b
      JOIN hotels h ON b.hotel_id = h.id AND h.host_id = ?
      JOIN rooms r  ON b.room_id  = r.id
      JOIN users u  ON b.user_id  = u.id
      WHERE 1=1
    `;
    const params: (string | number)[] = [hostId];

    if (status) { query += ` AND b.status = ?`; params.push(status as string); }
    query += ` ORDER BY b.created_at DESC LIMIT ? OFFSET ?`;
    params.push(Number(limit), (Number(page) - 1) * Number(limit));

    const [rows] = await pool.query<RowDataPacket[]>(query, params);
    res.json({ success: true, data: rows });
  } catch (error) {
    console.error('Get host bookings error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}
