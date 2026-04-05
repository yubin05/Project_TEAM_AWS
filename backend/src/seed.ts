import bcrypt from 'bcryptjs';
import { v4 as uuidv4 } from 'uuid';
import db, { initializeDatabase } from './models/database';

async function seed() {
  initializeDatabase();
  console.log('🌱 시드 데이터를 입력하는 중...');

  // Users
  const adminId = uuidv4();
  const hostId = uuidv4();
  const userId = uuidv4();
  const hashedPw = await bcrypt.hash('password123', 10);

  db.prepare(`INSERT OR IGNORE INTO users (id, email, password, name, phone, role) VALUES (?, ?, ?, ?, ?, ?)`).run(adminId, 'admin@travel.com', hashedPw, '관리자', '010-0000-0000', 'admin');
  db.prepare(`INSERT OR IGNORE INTO users (id, email, password, name, phone, role) VALUES (?, ?, ?, ?, ?, ?)`).run(hostId, 'host@travel.com', hashedPw, '호스트김', '010-1111-2222', 'host');
  db.prepare(`INSERT OR IGNORE INTO users (id, email, password, name, phone, role) VALUES (?, ?, ?, ?, ?, ?)`).run(userId, 'user@travel.com', hashedPw, '여행자이', '010-3333-4444', 'user');

  // Hotels data
  const hotelsData = [
    {
      id: uuidv4(), name: '그랜드 서울 호텔', description: '서울 중심부에 위치한 5성급 럭셔리 호텔입니다. 한강 뷰와 최고급 시설을 자랑합니다.',
      category: 'hotel', address: '서울특별시 중구 을지로 100', city: '서울', region: '서울/경기',
      latitude: 37.5665, longitude: 126.9780,
      amenities: ['수영장', '스파', '피트니스센터', '레스토랑', '바', '주차장', '조식포함', '와이파이'],
      images: ['https://images.unsplash.com/photo-1566073771259-6a8506099945?w=800', 'https://images.unsplash.com/photo-1564501049412-61c2a3083791?w=800'],
      check_in_time: '15:00', check_out_time: '11:00', rating: 4.8, review_count: 234
    },
    {
      id: uuidv4(), name: '제주 오션뷰 리조트', description: '제주 해안가에 위치한 프리미엄 리조트. 청정 제주 바다를 한눈에 담을 수 있습니다.',
      category: 'resort', address: '제주특별자치도 서귀포시 중문관광로 100', city: '제주', region: '제주',
      latitude: 33.2541, longitude: 126.4128,
      amenities: ['수영장', '해변', '스파', '레스토랑', '카페', '주차장', '조식포함', '와이파이', '바베큐'],
      images: ['https://images.unsplash.com/photo-1571896349842-33c89424de2d?w=800', 'https://images.unsplash.com/photo-1520250497591-112f2f40a3f4?w=800'],
      check_in_time: '15:00', check_out_time: '11:00', rating: 4.9, review_count: 456
    },
    {
      id: uuidv4(), name: '부산 해운대 호텔', description: '해운대 해수욕장 바로 앞! 탁 트인 바다 전망과 세련된 인테리어.',
      category: 'hotel', address: '부산광역시 해운대구 해운대해변로 200', city: '부산', region: '부산/경남',
      latitude: 35.1583, longitude: 129.1603,
      amenities: ['수영장', '레스토랑', '바', '주차장', '와이파이', '피트니스센터'],
      images: ['https://images.unsplash.com/photo-1551882547-ff40c63fe5fa?w=800', 'https://images.unsplash.com/photo-1578683010236-d716f9a3f461?w=800'],
      check_in_time: '14:00', check_out_time: '12:00', rating: 4.6, review_count: 187
    },
    {
      id: uuidv4(), name: '강릉 솔향 펜션', description: '강릉 바다와 소나무 숲 사이에 자리한 아늑한 펜션. 자연과 함께하는 힐링 여행.',
      category: 'pension', address: '강원특별자치도 강릉시 강동면 정동진리 100', city: '강릉', region: '강원',
      latitude: 37.7540, longitude: 129.0630,
      amenities: ['바베큐', '주차장', '와이파이', '바다뷰', '취사가능'],
      images: ['https://images.unsplash.com/photo-1510798831971-661eb04b3739?w=800', 'https://images.unsplash.com/photo-1499793983690-e29da59ef1c2?w=800'],
      check_in_time: '15:00', check_out_time: '11:00', rating: 4.5, review_count: 89
    },
    {
      id: uuidv4(), name: '경주 한옥 게스트하우스', description: '천년 고도 경주의 전통 한옥에서 즐기는 특별한 하룻밤. 역사와 문화를 담은 숙소.',
      category: 'guesthouse', address: '경상북도 경주시 교동 100', city: '경주', region: '대구/경북',
      latitude: 35.8420, longitude: 129.2115,
      amenities: ['한옥체험', '조식포함', '주차장', '와이파이', '문화체험'],
      images: ['https://images.unsplash.com/photo-1522202176988-66273c2fd55f?w=800', 'https://images.unsplash.com/photo-1518780664697-55e3ad937233?w=800'],
      check_in_time: '16:00', check_out_time: '10:00', rating: 4.7, review_count: 123
    },
    {
      id: uuidv4(), name: '여수 밤바다 모텔', description: '여수 밤바다가 보이는 아름다운 숙소. 합리적인 가격으로 최고의 전망을 즐기세요.',
      category: 'motel', address: '전라남도 여수시 돌산읍 돌산로 300', city: '여수', region: '광주/전라',
      latitude: 34.7604, longitude: 127.6622,
      amenities: ['바다뷰', '주차장', '와이파이', '에어컨'],
      images: ['https://images.unsplash.com/photo-1445019980597-93fa8acb246c?w=800', 'https://images.unsplash.com/photo-1449824913935-59a10b8d2000?w=800'],
      check_in_time: '14:00', check_out_time: '12:00', rating: 4.3, review_count: 67
    },
    {
      id: uuidv4(), name: '속초 설악 캠핑장', description: '설악산 국립공원 인근의 프리미엄 글램핑 캠핑장. 자연 속 럭셔리 캠핑을 경험하세요.',
      category: 'camping', address: '강원특별자치도 속초시 설악산로 1000', city: '속초', region: '강원',
      latitude: 38.2060, longitude: 128.5918,
      amenities: ['바베큐', '취사시설', '주차장', '와이파이', '샤워시설', '등산로'],
      images: ['https://images.unsplash.com/photo-1504280390367-361c6d9f38f4?w=800', 'https://images.unsplash.com/photo-1537225228614-56cc3556d7ed?w=800'],
      check_in_time: '14:00', check_out_time: '12:00', rating: 4.4, review_count: 45
    },
    {
      id: uuidv4(), name: '인천 공항 비즈니스 호텔', description: '인천국제공항 10분 거리의 편리한 비즈니스 호텔. 무료 셔틀버스 운행.',
      category: 'hotel', address: '인천광역시 중구 공항로 700', city: '인천', region: '서울/경기',
      latitude: 37.4602, longitude: 126.4407,
      amenities: ['공항셔틀', '주차장', '와이파이', '레스토랑', '피트니스센터', '비즈니스센터'],
      images: ['https://images.unsplash.com/photo-1590490360182-c33d57733427?w=800', 'https://images.unsplash.com/photo-1596386461350-326ccb383e9f?w=800'],
      check_in_time: '14:00', check_out_time: '12:00', rating: 4.2, review_count: 312
    }
  ];

  for (const hotel of hotelsData) {
    db.prepare(`
      INSERT OR IGNORE INTO hotels (id, host_id, name, description, category, address, city, region, latitude, longitude, amenities, images, check_in_time, check_out_time, rating, review_count)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    `).run(
      hotel.id, hostId, hotel.name, hotel.description, hotel.category,
      hotel.address, hotel.city, hotel.region, hotel.latitude, hotel.longitude,
      JSON.stringify(hotel.amenities), JSON.stringify(hotel.images),
      hotel.check_in_time, hotel.check_out_time, hotel.rating, hotel.review_count
    );

    // Add rooms for each hotel
    const roomTypes = [
      {
        name: '스탠다드 룸', description: '편안하고 깔끔한 스탠다드 객실',
        type: 'standard', capacity: 2, price: Math.floor(Math.random() * 50000) + 50000, discount: 0
      },
      {
        name: '디럭스 룸', description: '넓고 쾌적한 디럭스 객실',
        type: 'deluxe', capacity: 2, price: Math.floor(Math.random() * 80000) + 100000, discount: 10
      },
      {
        name: '패밀리 룸', description: '가족 여행에 최적화된 넓은 객실',
        type: 'family', capacity: 4, price: Math.floor(Math.random() * 100000) + 150000, discount: 5
      }
    ];

    for (const room of roomTypes) {
      const roomId = uuidv4();
      db.prepare(`
        INSERT OR IGNORE INTO rooms (id, hotel_id, name, description, type, capacity, price_per_night, discount_rate, images, amenities)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `).run(
        roomId, hotel.id, room.name, room.description, room.type,
        room.capacity, room.price, room.discount,
        JSON.stringify(hotel.images.slice(0, 1)),
        JSON.stringify(['에어컨', '미니바', 'TV', '욕실용품', '드라이기'])
      );
    }
  }

  console.log('✅ 시드 데이터 입력 완료!');
  console.log('\n📧 테스트 계정:');
  console.log('   관리자: admin@travel.com / password123');
  console.log('   호스트: host@travel.com / password123');
  console.log('   사용자: user@travel.com / password123');
}

seed().catch(console.error);
