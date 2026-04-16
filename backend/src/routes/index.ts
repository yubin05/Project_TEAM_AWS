import { Router } from 'express';
import { register, login, getProfile, updateProfile, changePassword } from '../controllers/authController';
import {
  searchHotels, getHotelById, createHotel, updateHotel,
  getRoomById, createRoom, checkRoomAvailability,
  getFeaturedHotels, getRegions, getMyHotels
} from '../controllers/hotelController';
import { createBooking, getUserBookings, getBookingById, cancelBooking, getHostBookings } from '../controllers/bookingController';
import { createReview, getHotelReviews, deleteReview, toggleWishlist, getWishlist } from '../controllers/reviewController';
import { authenticateToken, requireRole } from '../middleware/auth';

const router = Router();

// Auth routes
router.post('/auth/register', register);
router.post('/auth/login', login);
router.get('/auth/profile', authenticateToken, getProfile);
router.put('/auth/profile', authenticateToken, updateProfile);
router.put('/auth/password', authenticateToken, changePassword);

// Hotel routes
router.get('/hotels/featured', getFeaturedHotels);
router.get('/hotels/regions', getRegions);
router.get('/hotels/mine', authenticateToken, requireRole('host', 'admin'), getMyHotels);
router.get('/hotels/search', searchHotels);
router.get('/hotels/:id', getHotelById);
router.post('/hotels', authenticateToken, requireRole('host', 'admin'), createHotel);
router.put('/hotels/:id', authenticateToken, requireRole('host', 'admin'), updateHotel);

// Room routes
router.get('/hotels/:hotelId/rooms/:roomId', getRoomById);
router.get('/hotels/:hotelId/rooms/:roomId/availability', checkRoomAvailability);
router.post('/hotels/:hotelId/rooms', authenticateToken, requireRole('host', 'admin'), createRoom);

// Booking routes
router.post('/bookings', authenticateToken, createBooking);
router.get('/bookings', authenticateToken, getUserBookings);
router.get('/bookings/host', authenticateToken, requireRole('host', 'admin'), getHostBookings);
router.get('/bookings/:id', authenticateToken, getBookingById);
router.delete('/bookings/:id', authenticateToken, cancelBooking);

// Review routes
router.get('/hotels/:hotelId/reviews', getHotelReviews);
router.post('/reviews', authenticateToken, createReview);
router.delete('/reviews/:id', authenticateToken, deleteReview);

// Wishlist routes
router.post('/wishlist/:hotelId', authenticateToken, toggleWishlist);
router.get('/wishlist', authenticateToken, getWishlist);

export default router;
