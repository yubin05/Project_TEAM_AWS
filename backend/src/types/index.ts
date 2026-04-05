export interface User {
  id: string;
  email: string;
  password: string;
  name: string;
  phone?: string;
  profile_image?: string;
  role: 'user' | 'host' | 'admin';
  created_at: string;
  updated_at: string;
}

export interface Hotel {
  id: string;
  host_id: string;
  name: string;
  description: string;
  category: 'hotel' | 'motel' | 'pension' | 'guesthouse' | 'resort' | 'camping';
  address: string;
  city: string;
  region: string;
  latitude?: number;
  longitude?: number;
  amenities: string; // JSON array string
  images: string;   // JSON array string
  check_in_time: string;
  check_out_time: string;
  rating: number;
  review_count: number;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface Room {
  id: string;
  hotel_id: string;
  name: string;
  description: string;
  type: 'standard' | 'deluxe' | 'suite' | 'family' | 'dormitory';
  capacity: number;
  price_per_night: number;
  discount_rate: number;
  images: string; // JSON array string
  amenities: string; // JSON array string
  is_available: boolean;
  created_at: string;
  updated_at: string;
}

export interface Booking {
  id: string;
  user_id: string;
  hotel_id: string;
  room_id: string;
  check_in_date: string;
  check_out_date: string;
  guests: number;
  total_price: number;
  status: 'pending' | 'confirmed' | 'cancelled' | 'completed';
  special_requests?: string;
  created_at: string;
  updated_at: string;
}

export interface Review {
  id: string;
  user_id: string;
  hotel_id: string;
  booking_id: string;
  rating: number;
  title: string;
  content: string;
  images: string; // JSON array string
  created_at: string;
  updated_at: string;
}

export interface JwtPayload {
  userId: string;
  email: string;
  role: string;
}

export interface SearchQuery {
  city?: string;
  region?: string;
  category?: string;
  check_in?: string;
  check_out?: string;
  guests?: number;
  min_price?: number;
  max_price?: number;
  amenities?: string[];
  sort_by?: 'price_asc' | 'price_desc' | 'rating' | 'popular';
  page?: number;
  limit?: number;
}
