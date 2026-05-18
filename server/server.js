const express = require('express');
const mysql = require('mysql2');
const cors = require('cors');
const jwt = require('jsonwebtoken');
const bcrypt = require('bcrypt');

const app = express();
app.use(cors());
app.use(express.json());

const JWT_SECRET = 'my_super_secret_parking_key_2026!';

// 🗄️ DB 연결 정보 수정
const db = mysql.createConnection({
    host: 'localhost',
    user: 'root',
    password: 'shf3717!', 
    database: 'parking_db' // 👈 'datasample'에서 다시 'parking_db'로 변경!
});

db.connect(err => {
    if (err) return console.error('❌ DB 연결 실패:', err);
    console.log('✅ MySQL 연결 성공!');
});

// 🔒 [미들웨어] 토큰을 확인해서 누구인지(u_no) 알아내는 도구
const authenticateToken = (req, res, next) => {
    const authHeader = req.headers['authorization'];
    const token = authHeader && authHeader.split(' ')[1];
    if (!token) return res.sendStatus(401);

    jwt.verify(token, JWT_SECRET, (err, user) => {
        if (err) return res.sendStatus(403);
        req.user = user;
        next();
    });
};

// ---------------------------------------------------------
// 1. 계정 관련 API (로그인, 회원가입, 찾기, 내정보)
// ---------------------------------------------------------

// 🚀 로그인 API (로그 추가 버전)
app.post('/api/login', (req, res) => {
    const { u_id, u_pwd } = req.body;
    console.log(`📩 로그인 시도 아이디: ${u_id}`); // 👈 서버 터미널에 아이디가 찍히는지 확인하세요

    const query = 'SELECT * FROM user WHERE u_id = ?';
    db.query(query, [u_id], async (err, results) => {
        if (err) {
            console.error("❌ DB 조회 에러:", err);
            return res.status(500).json({ success: false });
        }

        if (results.length > 0) {
            const user = results[0];
            // 💡 중요: DB에 비번을 직접 넣으셨다면 bcrypt.compare에서 실패할 확률이 높습니다.
            const isMatch = await bcrypt.compare(u_pwd, user.u_pwd);
            
            if (isMatch) {
                console.log("✅ 비밀번호 일치 - 로그인 성공");
                const token = jwt.sign({ userId: user.u_no }, JWT_SECRET, { expiresIn: '2h' });
                res.json({ 
                    success: true, 
                    token: token, 
                    // 💡 앱의 login_screen.dart에서 'user' 객체가 없으면 멈출 수 있으므로 반드시 포함!
                    user: { u_id: user.u_id, approval_status: user.approval_status || 'APPROVED' } 
                });
            } else { 
                console.log("❌ 비밀번호 불일치");
                res.status(401).json({ success: false, message: '비번 틀림' }); 
            }
        } else { 
            console.log("❌ 아이디 없음");
            res.status(404).json({ success: false, message: '아이디 없음' }); 
        }
    });
});
// 🚀 회원가입
app.post('/api/signup', async (req, res) => {
    const { u_id, u_pwd, u_name, u_email, u_phone, u_dong, u_ho, a_no } = req.body;
    try {
        const hashedPwd = await bcrypt.hash(u_pwd, 10);
        const query = `INSERT INTO user (u_id, u_pwd, u_name, u_email, u_phone, u_dong, u_ho, a_no, approval_status) VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'APPROVED')`;
        db.query(query, [u_id, hashedPwd, u_name, u_email, u_phone, u_dong, u_ho, a_no], (err) => {
            if (err) return res.status(500).json({ success: false, message: '중복 가입' });
            res.json({ success: true });
        });
    } catch (e) { res.status(500).json({ success: false }); }
});

// 🚀 아이디 찾기
app.post('/api/find-id', (req, res) => {
    const { u_dong, u_ho, apt_pwd } = req.body;
    const query = `SELECT u.u_id FROM user u JOIN apartments a ON u.a_no = a.a_no WHERE u.u_dong = ? AND u.u_ho = ? AND a.a_pwd = ?`;
    db.query(query, [u_dong, u_ho, apt_pwd], (err, results) => {
        if (results.length > 0) res.json({ success: true, u_id: results[0].u_id });
        else res.status(404).json({ success: false });
    });
});

// 🚀 비밀번호 재설정 (새로 추가됨)
app.post('/api/reset-pw', async (req, res) => {
    const { u_id, u_dong, u_ho, newPassword } = req.body;
    const hashedNewPwd = await bcrypt.hash(newPassword, 10);
    const query = 'UPDATE user SET u_pwd = ? WHERE u_id = ? AND u_dong = ? AND u_ho = ?';
    db.query(query, [hashedNewPwd, u_id, u_dong, u_ho], (err, result) => {
        if (result.affectedRows > 0) res.json({ success: true });
        else res.status(404).json({ success: false });
    });
});

// 🚀 내 정보 조회 (설정 화면용)
app.get('/api/user-info', authenticateToken, (req, res) => {
    const query = 'SELECT u_name, u_dong, u_ho FROM user WHERE u_no = ?';
    db.query(query, [req.user.userId], (err, results) => {
        if (results.length > 0) res.json({ success: true, user: results[0] });
        else res.sendStatus(404);
    });
});

// ---------------------------------------------------------
// 2. 차량 관리 API (분리된 DB 테이블 완벽 적용 버전)
// ---------------------------------------------------------

// 🚀 차량 목록 조회 (입주민 + 방문객 따로 챙겨서 보내기)
app.get('/api/cars', authenticateToken, (req, res) => {
    const u_no = req.user.userId;

    // 1. 입주민 차량 조회
    db.query('SELECT * FROM car WHERE u_no = ?', [u_no], (err, residentResults) => {
        if (err) return res.status(500).json({ success: false });

        // 2. 방문객 차량 조회
        db.query('SELECT * FROM registered_cars WHERE u_no = ?', [u_no], (err, visitorResults) => {
            if (err) return res.status(500).json({ success: false });

            // 3. 앱이 편하게 쓰도록 두 덩어리로 나눠서 포장해 보내기
            res.json({ 
                success: true, 
                resident_cars: residentResults, 
                visitor_cars: visitorResults 
            });
        });
    });
});

// 🚀 차량 등록 (입주민/방문객 구분해서 다른 테이블에 넣기)
app.post('/api/cars', authenticateToken, (req, res) => {
    const { c_number, c_name, car_type, c_note } = req.body;
    const u_no = req.user.userId;

    if (car_type === '방문객') {
        // 방문객은 registered_cars 테이블로! (만료시간은 지금으로부터 24시간 뒤로 자동 계산)
        const query = `INSERT INTO registered_cars (u_no, c_number, expire_date) VALUES (?, ?, DATE_ADD(NOW(), INTERVAL 1 DAY))`;
        db.query(query, [u_no, c_number], (err) => {
            if (err) return res.status(500).json({ success: false, message: '방문객 등록 에러' });
            res.json({ success: true });
        });
    } else {
        // 입주민은 기존 car 테이블로!
        const query = `INSERT INTO car (u_no, c_number, c_name, c_kind, c_note, c_date) VALUES (?, ?, ?, '입주민', ?, NOW())`;
        db.query(query, [u_no, c_number, c_name, c_note], (err) => {
            if (err) return res.status(500).json({ success: false, message: '입주민 등록 에러' });
            res.json({ success: true });
        });
    }
});
// 🚗 차량 삭제 API (입주민/방문객 통합)
app.delete('/api/cars/:carNumber', authenticateToken, (req, res) => {
    const carNumber = req.params.carNumber;
    const u_no = req.user.userId;

    // 1. 먼저 입주민 차량 테이블(car)에서 삭제 시도
    const deleteResident = 'DELETE FROM car WHERE c_number = ? AND u_no = ?';
    
    db.query(deleteResident, [carNumber, u_no], (err, result) => {
        if (err) return res.status(500).json({ success: false });

        // 만약 입주민 차량에서 지워진 게 있다면 성공 응답
        if (result.affectedRows > 0) {
            return res.json({ success: true, message: '입주민 차량 삭제 완료' });
        }

        // 2. 지워진 게 없다면 방문객 차량 테이블(registered_cars)에서 삭제 시도
        const deleteVisitor = 'DELETE FROM registered_cars WHERE c_number = ? AND u_no = ?';
        db.query(deleteVisitor, [carNumber, u_no], (err, result) => {
            if (err) return res.status(500).json({ success: false });

            if (result.affectedRows > 0) {
                res.json({ success: true, message: '방문객 차량 삭제 완료' });
            } else {
                res.status(404).json({ success: false, message: '삭제할 차량을 찾을 수 없습니다.' });
            }
        });
    });
});
// ---------------------------------------------------------
// 3. 주차 및 기타 API
// ---------------------------------------------------------

// 🚀 주차장 현황 (수정 완료: 웹팀 DB의 영어 상태값 호환)
app.get('/api/parking-zones', (req, res) => {
    const query = `SELECT area_number AS slot, status, current_car_number FROM parking_zone ORDER BY pz_no ASC`;
    db.query(query, (err, results) => {
        if (err) {
            console.error("❌ 주차장 조회 DB 에러:", err);
            return res.status(500).json({ success: false });
        }

        let zones = results.map(r => ({
            floor: "B1", 
            type: r.slot.includes('통로') ? 'aisle' : 'slot', 
            slot: r.slot, 
            // 💡 핵심 수정: 한글 '사용중'과 영어 'occupied'를 모두 인식하도록 변경!
            isOccupied: r.status === '사용중' || r.status === 'occupied', 
            current_car_number: r.current_car_number 
        }));

        res.json({ success: true, zones: zones });
    });
});
// 🚀 알림 목록 조회
app.get('/api/notifications', authenticateToken, (req, res) => {
    const query = 'SELECT * FROM notifications WHERE u_no = ? ORDER BY created_at DESC';
    db.query(query, [req.user.userId], (err, results) => {
        res.json({ success: true, notifications: results });
    });
});

// ---------------------------------------------------------
// 🚀 문의 내역 조회 (수정 완료: resident_inquiry 테이블 사용)
app.get('/api/inquiries', authenticateToken, (req, res) => {
    // 💡 inquiries -> resident_inquiry 로 변경
    const query = 'SELECT * FROM resident_inquiry WHERE u_no = ? ORDER BY created_at DESC';
    
    db.query(query, [req.user.userId], (err, results) => {
        if (err) {
            console.error("❌ 문의 조회 DB 에러:", err);
            return res.status(500).json({ success: false, message: 'DB 조회 실패' });
        }
        res.json({ success: true, inquiries: results });
    });
});

// 🚀 문의 내역 등록 (웹팀 DB 구조 완벽 반영)
app.post('/api/inquiries', authenticateToken, (req, res) => {
    // 💡 category가 빠지고, c_no(선택)가 추가되었습니다.
    const { title, content, c_no } = req.body; 
    
    // 💡 resident_inquiry 테이블에 status 기본값을 'pending'으로 넣습니다.
    const query = 'INSERT INTO resident_inquiry (u_no, c_no, title, content, status) VALUES (?, ?, ?, ?, "pending")';
    
    // c_no가 없으면 null을 넣도록 처리
    db.query(query, [req.user.userId, c_no || null, title, content], (err, result) => {
        if (err) {
            console.error("❌ 문의 등록 DB 에러:", err); 
            return res.status(500).json({ success: false, message: 'DB 저장 실패' });
        }
        console.log("✅ 문의 등록 완료!");
        res.json({ success: true });
    });
});
// ---------------------------------------------------------
// 🚀 알림 대기 신청 (에러 추적 기능 추가)
app.post('/api/waitlist', authenticateToken, (req, res) => {
    const { target_slot_id } = req.body;
    const query = 'INSERT INTO waiting_list (u_no, target_slot_id) VALUES (?, ?)';
    db.query(query, [req.user.userId, target_slot_id], (err, result) => {
        if (err) {
            console.error("❌ 알림 대기 DB 에러:", err);
            return res.status(500).json({ success: false, message: 'DB 저장 실패' });
        }
        console.log("✅ 알림 대기 신청 완료!");
        res.json({ success: true });
    });
});
// 🚀 아파트 목록 조회
app.get('/api/apartments', (req, res) => {
    db.query('SELECT a_no, a_name FROM apartments', (err, results) => {
        res.json({ success: true, apartments: results });
    });
});
// ---------------------------------------------------------
// 🚀 4. 앱 부가 기능 API (알림 읽음, 기기 토큰, 설정 동기화)
// ---------------------------------------------------------

// ✅ 알림 읽음 처리
app.patch('/api/notifications/:id/read', authenticateToken, (req, res) => {
    const notiNo = req.params.id;
    const query = 'UPDATE notifications SET is_read = 1 WHERE noti_no = ? AND u_no = ?';
    db.query(query, [notiNo, req.user.userId], (err, result) => {
        if (err) return res.status(500).json({ success: false });
        res.json({ success: true });
    });
});

// ✅ 기기 알림 토큰(FCM) 저장 (로그인 시 작동)
app.post('/api/device-token', authenticateToken, (req, res) => {
    const { fcm_token } = req.body;
    const tempDeviceId = 'device_' + req.user.userId; // 임시 디바이스 ID 생성
    const query = `
        INSERT INTO device_info (device_id, u_no, fcm_token) 
        VALUES (?, ?, ?) 
        ON DUPLICATE KEY UPDATE fcm_token = ?`;
    db.query(query, [tempDeviceId, req.user.userId, fcm_token, fcm_token], (err) => {
        if (err) return res.status(500).json({ success: false });
        res.json({ success: true });
    });
});

// ✅ 기기 알림 토큰(FCM) 삭제 (로그아웃 시 작동)
app.delete('/api/device-token', authenticateToken, (req, res) => {
    const query = 'UPDATE device_info SET fcm_token = NULL WHERE u_no = ?';
    db.query(query, [req.user.userId], (err) => {
        if (err) return res.status(500).json({ success: false });
        res.json({ success: true });
    });
});

// ✅ 앱 설정 저장 (푸시 알림 ON/OFF)
app.patch('/api/settings/push', authenticateToken, (req, res) => {
    const { alert_push } = req.body;
    const tempDeviceId = 'device_' + req.user.userId;
    const query = `INSERT INTO settings (device_id, alert_push) VALUES (?, ?) ON DUPLICATE KEY UPDATE alert_push = ?`;
    db.query(query, [tempDeviceId, alert_push, alert_push], (err) => {
        if (err) return res.status(500).json({ success: false });
        res.json({ success: true });
    });
});

// ✅ 앱 설정 저장 (다크 모드 ON/OFF)
app.patch('/api/settings/theme', authenticateToken, (req, res) => {
    const { theme_mode } = req.body;
    const tempDeviceId = 'device_' + req.user.userId;
    const query = `INSERT INTO settings (device_id, theme_mode) VALUES (?, ?) ON DUPLICATE KEY UPDATE theme_mode = ?`;
    db.query(query, [tempDeviceId, theme_mode, theme_mode], (err) => {
        if (err) return res.status(500).json({ success: false });
        res.json({ success: true });
    });
});
app.listen(3000, () => console.log('🚀 통합 서버 실행 중: http://localhost:3000'));