import { Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import { RowDataPacket } from 'mysql2';
import pool from '../models/pool';
import { translateFields } from '../services/translateService';
import { Hotel, Room, SearchQuery } from '../types';

export async function searchHotels(req: Request, res: Response): Promise<void> {
  try {
    const {
      city, region, category, check_in, check_out,
      guests, min_price, max_price, sort_by = 'popular',
      page = 1, limit = 10, lang = 'ko',
    } = req.query as unknown as SearchQuery & { lang?: string };

    let query = `
      SELECT h.*,
        MIN(r.price_per_night * (1 - r.discount_rate / 100)) as min_price,
        GROUP_CONCAT(DISTINCT r.id) as room_ids
      FROM hotels h
      LEFT JOIN rooms r ON h.id = r.hotel_id AND r.is_available = 1
      WHERE h.is_active = 1
    `;
    const params: (string | number)[] = [];

    if (city)     { query += ` AND h.city LIKE ?`;     params.push(`%${city}%`); }
    if (region)   { query += ` AND h.region LIKE ?`;   params.push(`%${region}%`); }
    if (category) { query += ` AND h.category = ?`;    params.push(category); }

    if (check_in && check_out) {
      query += `
        AND h.id NOT IN (
          SELECT DISTINCT b.hotel_id FROM bookings b
          WHERE b.status IN ('confirmed','pending')
          AND b.check_in_date < ? AND b.check_out_date > ?
          GROUP BY b.hotel_id, b.room_id
          HAVING COUNT(*) >= (SELECT COUNT(*) FROM rooms WHERE hotel_id = b.hotel_id AND is_available = 1)
        )
      `;
      params.push(check_out, check_in);
    }

    if (guests) {
      query += ` AND h.id IN (SELECT hotel_id FROM rooms WHERE capacity >= ? AND is_available = 1)`;
      params.push(Number(guests));
    }

    query += ` GROUP BY h.id`;

    if (min_price) { query += ` HAVING min_price >= ?`;                             params.push(Number(min_price)); }
    if (max_price) { query += ` ${min_price ? 'AND' : 'HAVING'} min_price <= ?`;   params.push(Number(max_price)); }

    switch (sort_by) {
      case 'price_asc':  query += ' ORDER BY min_price ASC';  break;
      case 'price_desc': query += ' ORDER BY min_price DESC'; break;
      case 'rating':     query += ' ORDER BY h.rating DESC';  break;
      default:           query += ' ORDER BY h.review_count DESC, h.rating DESC';
    }

    const offset = (Number(page) - 1) * Number(limit);
    query += ` LIMIT ? OFFSET ?`;
    params.push(Number(limit), offset);

    const [rows] = await pool.execute<RowDataPacket[]>(query, params);
    const hotels  = rows as (Hotel & { min_price: number })[];

    const [countRows] = await pool.execute<RowDataPacket[]>(
      `SELECT COUNT(DISTINCT h.id) as total FROM hotels h WHERE h.is_active = 1
       ${city     ? `AND h.city LIKE ?`     : ''}
       ${region   ? `AND h.region LIKE ?`   : ''}
       ${category ? `AND h.category = ?`    : ''}`,
      [
        ...(city     ? [`%${city}%`]     : []),
        ...(region   ? [`%${region}%`]   : []),
        ...(category ? [category]        : []),
      ]
    );
    const total = (countRows[0] as { total: number }).total;

    let result = hotels.map(h => ({
      ...h,
      amenities: typeof h.amenities === 'string' ? JSON.parse(h.amenities) : h.amenities,
      images:    typeof h.images    === 'string' ? JSON.parse(h.images)    : h.images,
      is_active: Boolean(h.is_active),
    }));

    result = await translateFields(result, ['name', 'description'], lang ?? 'ko') as typeof result;

    res.json({
      success: true,
      data: {
        hotels: result,
        pagination: { total, page: Number(page), limit: Number(limit), total_pages: Math.ceil(total / Number(limit)) },
      },
    });
  } catch (error) {
    console.error('Search hotels error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getHotelById(req: Request, res: Response): Promise<void> {
  try {
    const { id } = req.params;
    const lang = (req.query.lang as string) || 'ko';

    const [hotelRows] = await pool.execute<RowDataPacket[]>(
      'SELECT * FROM hotels WHERE id = ? AND is_active = 1', [id]
    );
    const hotel = (hotelRows as RowDataPacket[])[0] as Hotel | undefined;
    if (!hotel) {
      res.status(404).json({ success: false, message: '숙소를 찾을 수 없습니다.' });
      return;
    }

    const [roomRows]   = await pool.execute<RowDataPacket[]>('SELECT * FROM rooms WHERE hotel_id = ?', [id]);
    const [reviewRows] = await pool.execute<RowDataPacket[]>(`
      SELECT r.*, u.name as user_name, u.profile_image as user_avatar
      FROM reviews r JOIN users u ON r.user_id = u.id
      WHERE r.hotel_id = ? ORDER BY r.created_at DESC LIMIT 10
    `, [id]);

    const rooms   = roomRows as Room[];
    const reviews = reviewRows as RowDataPacket[];

    res.json({
      success: true,
      data: {
        ...hotel,
        amenities: typeof hotel.amenities === 'string' ? JSON.parse(hotel.amenities) : hotel.amenities,
        images:    typeof hotel.images    === 'string' ? JSON.parse(hotel.images)    : hotel.images,
        is_active: Boolean(hotel.is_active),
        rooms: rooms.map(r => ({
          ...r,
          amenities:        typeof r.amenities === 'string' ? JSON.parse(r.amenities) : r.amenities,
          images:           typeof r.images    === 'string' ? JSON.parse(r.images)    : r.images,
          is_available:     Boolean(r.is_available),
          discounted_price: Number(r.price_per_night) * (1 - Number(r.discount_rate) / 100),
        })),
        reviews,
      },
    });
  } catch (error) {
    console.error('Get hotel error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function createHotel(req: Request, res: Response): Promise<void> {
  try {
    const {
      name, description, category, address, city, region,
      latitude, longitude, amenities = [], images = [],
      check_in_time = '15:00', check_out_time = '11:00',
    } = req.body;

    if (!name || !description || !category || !address || !city || !region) {
      res.status(400).json({ success: false, message: '필수 정보를 모두 입력해주세요.' });
      return;
    }

    const hotelId = uuidv4();
    await pool.execute(
      `INSERT INTO hotels (id, host_id, name, description, category, address, city, region,
        latitude, longitude, amenities, images, check_in_time, check_out_time)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [
        hotelId, req.user!.userId, name, description, category,
        address, city, region, latitude ?? null, longitude ?? null,
        JSON.stringify(amenities), JSON.stringify(images),
        check_in_time, check_out_time,
      ]
    );

    res.status(201).json({ success: true, message: '숙소가 등록되었습니다.', data: { id: hotelId } });
  } catch (error) {
    console.error('Create hotel error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function updateHotel(req: Request, res: Response): Promise<void> {
  try {
    const { id } = req.params;

    const [rows] = await pool.execute<RowDataPacket[]>('SELECT * FROM hotels WHERE id = ?', [id]);
    const hotel = (rows as RowDataPacket[])[0] as Hotel | undefined;
    if (!hotel) {
      res.status(404).json({ success: false, message: '숙소를 찾을 수 없습니다.' });
      return;
    }
    if (hotel.host_id !== req.user!.userId && req.user!.role !== 'admin') {
      res.status(403).json({ success: false, message: '권한이 없습니다.' });
      return;
    }

    const { name, description, address, amenities, images, check_in_time, check_out_time, is_active } = req.body;

    await pool.execute(
      `UPDATE hotels SET
        name           = COALESCE(?, name),
        description    = COALESCE(?, description),
        address        = COALESCE(?, address),
        amenities      = COALESCE(?, amenities),
        images         = COALESCE(?, images),
        check_in_time  = COALESCE(?, check_in_time),
        check_out_time = COALESCE(?, check_out_time),
        is_active      = COALESCE(?, is_active)
       WHERE id = ?`,
      [
        name ?? null, description ?? null, address ?? null,
        amenities ? JSON.stringify(amenities) : null,
        images    ? JSON.stringify(images)    : null,
        check_in_time ?? null, check_out_time ?? null,
        is_active !== undefined ? (is_active ? 1 : 0) : null,
        id,
      ]
    );

    res.json({ success: true, message: '숙소 정보가 업데이트되었습니다.' });
  } catch (error) {
    console.error('Update hotel error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getRoomById(req: Request, res: Response): Promise<void> {
  try {
    const { hotelId, roomId } = req.params;
    const [rows] = await pool.execute<RowDataPacket[]>(
      'SELECT * FROM rooms WHERE id = ? AND hotel_id = ?', [roomId, hotelId]
    );
    const room = (rows as RowDataPacket[])[0] as Room | undefined;
    if (!room) {
      res.status(404).json({ success: false, message: '객실을 찾을 수 없습니다.' });
      return;
    }

    res.json({
      success: true,
      data: {
        ...room,
        amenities:        typeof room.amenities === 'string' ? JSON.parse(room.amenities) : room.amenities,
        images:           typeof room.images    === 'string' ? JSON.parse(room.images)    : room.images,
        is_available:     Boolean(room.is_available),
        discounted_price: Number(room.price_per_night) * (1 - Number(room.discount_rate) / 100),
      },
    });
  } catch (error) {
    console.error('Get room error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function createRoom(req: Request, res: Response): Promise<void> {
  try {
    const { hotelId } = req.params;

    const [rows] = await pool.execute<RowDataPacket[]>('SELECT * FROM hotels WHERE id = ?', [hotelId]);
    const hotel = (rows as RowDataPacket[])[0] as Hotel | undefined;
    if (!hotel) {
      res.status(404).json({ success: false, message: '숙소를 찾을 수 없습니다.' });
      return;
    }
    if (hotel.host_id !== req.user!.userId && req.user!.role !== 'admin') {
      res.status(403).json({ success: false, message: '권한이 없습니다.' });
      return;
    }

    const { name, description, type, capacity, price_per_night, discount_rate = 0, images = [], amenities = [] } = req.body;
    if (!name || !description || !type || !capacity || !price_per_night) {
      res.status(400).json({ success: false, message: '필수 정보를 모두 입력해주세요.' });
      return;
    }

    const roomId = uuidv4();
    await pool.execute(
      `INSERT INTO rooms (id, hotel_id, name, description, type, capacity, price_per_night, discount_rate, images, amenities)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      [roomId, hotelId, name, description, type, capacity, price_per_night, discount_rate, JSON.stringify(images), JSON.stringify(amenities)]
    );

    res.status(201).json({ success: true, message: '객실이 등록되었습니다.', data: { id: roomId } });
  } catch (error) {
    console.error('Create room error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function checkRoomAvailability(req: Request, res: Response): Promise<void> {
  try {
    const { hotelId, roomId } = req.params;
    const { check_in, check_out } = req.query;

    if (!check_in || !check_out) {
      res.status(400).json({ success: false, message: '체크인/체크아웃 날짜를 입력해주세요.' });
      return;
    }

    const [rows] = await pool.execute<RowDataPacket[]>(
      `SELECT COUNT(*) as count FROM bookings
       WHERE room_id = ? AND hotel_id = ?
       AND status IN ('confirmed','pending')
       AND check_in_date < ? AND check_out_date > ?`,
      [roomId, hotelId, check_out, check_in]
    );
    const count = ((rows as RowDataPacket[])[0] as { count: number }).count;

    res.json({ success: true, data: { available: count === 0 } });
  } catch (error) {
    console.error('Check availability error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getFeaturedHotels(req: Request, res: Response): Promise<void> {
  try {
    const lang = (req.query.lang as string) || 'ko';

    const [rows] = await pool.execute<RowDataPacket[]>(`
      SELECT h.*, MIN(r.price_per_night * (1 - r.discount_rate / 100)) as min_price
      FROM hotels h
      LEFT JOIN rooms r ON h.id = r.hotel_id AND r.is_available = 1
      WHERE h.is_active = 1
      GROUP BY h.id
      ORDER BY h.rating DESC, h.review_count DESC
      LIMIT 8
    `);

    let result = (rows as (Hotel & { min_price: number })[]).map(h => ({
      ...h,
      amenities: typeof h.amenities === 'string' ? JSON.parse(h.amenities) : h.amenities,
      images:    typeof h.images    === 'string' ? JSON.parse(h.images)    : h.images,
      is_active: Boolean(h.is_active),
    }));

    result = await translateFields(result, ['name', 'description'], lang) as typeof result;

    res.json({ success: true, data: result });
  } catch (error) {
    console.error('Get featured hotels error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}

export async function getRegions(req: Request, res: Response): Promise<void> {
  try {
    const [rows] = await pool.execute<RowDataPacket[]>(`
      SELECT region, city, COUNT(*) as hotel_count
      FROM hotels WHERE is_active = 1
      GROUP BY region, city
      ORDER BY hotel_count DESC
    `);
    res.json({ success: true, data: rows });
  } catch (error) {
    console.error('Get regions error:', error);
    res.status(500).json({ success: false, message: '서버 오류가 발생했습니다.' });
  }
}
