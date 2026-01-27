const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const { v4: uuidv4 } = require('uuid');

const app = express();
const PORT = process.env.PORT || 3000;

// Configuración de PostgreSQL
const pool = new Pool({
  host: process.env.DB_HOST || 'postgres',
  port: process.env.DB_PORT || 5432,
  database: process.env.DB_NAME || 'pai_database',
  user: process.env.DB_USER || 'pai_admin',
  password: process.env.DB_PASSWORD || 'pai_secure_password_2026',
});

const JWT_SECRET = process.env.JWT_SECRET || 'super-secret-jwt-token-for-pai-app-2026-must-be-32-chars';

// Middleware
app.use(cors());
app.use(express.json());

// Middleware de autenticación
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) {
    return res.status(401).json({ error: 'Token requerido' });
  }

  jwt.verify(token, JWT_SECRET, (err, user) => {
    if (err) {
      return res.status(403).json({ error: 'Token inválido' });
    }
    req.user = user;
    next();
  });
};

// =====================================================
// RUTAS DE AUTENTICACIÓN
// =====================================================

// Login
app.post('/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;
    console.log(`🔐 Intento de login: ${email}`);

    // Normalizar email (si es solo número, agregar dominio)
    let normalizedEmail = email.trim();
    if (!normalizedEmail.includes('@')) {
      normalizedEmail = `${normalizedEmail}@conductor.app`;
    }

    const result = await pool.query(
      'SELECT * FROM profiles WHERE email = $1 AND is_active = true',
      [normalizedEmail]
    );

    if (result.rows.length === 0) {
      console.log(`❌ Usuario no encontrado: ${normalizedEmail}`);
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const user = result.rows[0];
    const validPassword = await bcrypt.compare(password, user.password_hash);

    if (!validPassword) {
      console.log(`❌ Contraseña incorrecta para: ${normalizedEmail}`);
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    console.log(`✅ Login exitoso: ${normalizedEmail} (${user.role})`);

    res.json({
      access_token: token,
      user: {
        id: user.id,
        email: user.email,
        full_name: user.full_name,
        role: user.role,
        assigned_vehicle_id: user.assigned_vehicle_id,
      },
    });
  } catch (error) {
    console.error('❌ Error en login:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Registro de nuevo usuario/conductor
app.post('/auth/signup', async (req, res) => {
  try {
    const { email, password, full_name, role = 'driver', assigned_vehicle_id } = req.body;
    
    // Normalizar email
    let normalizedEmail = email.trim();
    if (!normalizedEmail.includes('@')) {
      normalizedEmail = `${normalizedEmail}@conductor.app`;
    }

    console.log(`📝 Registrando usuario: ${normalizedEmail}`);

    // Verificar si ya existe
    const existing = await pool.query(
      'SELECT id FROM profiles WHERE email = $1',
      [normalizedEmail]
    );

    if (existing.rows.length > 0) {
      return res.status(400).json({ error: 'El usuario ya existe' });
    }

    // Hashear contraseña
    const password_hash = await bcrypt.hash(password, 10);

    // Insertar usuario
    const result = await pool.query(
      `INSERT INTO profiles (email, password_hash, full_name, role, assigned_vehicle_id)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, email, full_name, role, assigned_vehicle_id, created_at`,
      [normalizedEmail, password_hash, full_name, role, assigned_vehicle_id]
    );

    const newUser = result.rows[0];

    const token = jwt.sign(
      { id: newUser.id, email: newUser.email, role: newUser.role },
      JWT_SECRET,
      { expiresIn: '7d' }
    );

    console.log(`✅ Usuario creado: ${normalizedEmail}`);

    res.status(201).json({
      access_token: token,
      user: newUser,
    });
  } catch (error) {
    console.error('❌ Error en registro:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Obtener usuario actual
app.get('/auth/user', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, full_name, role, assigned_vehicle_id, phone, avatar_url FROM profiles WHERE id = $1',
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error obteniendo usuario:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE PROFILES (Conductores)
// =====================================================

// Obtener todos los conductores
app.get('/rest/v1/profiles', authenticateToken, async (req, res) => {
  try {
    const { role, select } = req.query;
    
    let query = 'SELECT * FROM profiles WHERE is_active = true';
    const params = [];

    if (role) {
      params.push(role.replace('eq.', ''));
      query += ` AND role = $${params.length}`;
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo profiles:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Obtener un conductor por ID
app.get('/rest/v1/profiles/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM profiles WHERE id = $1',
      [req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error obteniendo perfil:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Actualizar perfil
app.patch('/rest/v1/profiles/:id', authenticateToken, async (req, res) => {
  try {
    const { full_name, assigned_vehicle_id, phone, role } = req.body;
    
    const result = await pool.query(
      `UPDATE profiles 
       SET full_name = COALESCE($1, full_name),
           assigned_vehicle_id = $2,
           phone = COALESCE($3, phone),
           role = COALESCE($4, role)
       WHERE id = $5
       RETURNING *`,
      [full_name, assigned_vehicle_id, phone, role, req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error actualizando perfil:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE VEHICLES
// =====================================================

// Obtener todos los vehículos
app.get('/rest/v1/vehicles', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM vehicles WHERE is_active = true ORDER BY placa'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo vehículos:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Crear vehículo
app.post('/rest/v1/vehicles', authenticateToken, async (req, res) => {
  try {
    const { placa, marca, modelo, ano, color, tipo, gps_device_id } = req.body;

    const result = await pool.query(
      `INSERT INTO vehicles (placa, marca, modelo, ano, color, tipo, gps_device_id, owner_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [placa, marca, modelo, ano, color, tipo, gps_device_id, req.user.id]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando vehículo:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE VEHICLE HISTORY
// =====================================================

// Guardar ubicación
app.post('/rest/v1/vehicle_history', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id, latitude, longitude, speed, altitude, heading, accuracy, address } = req.body;

    const result = await pool.query(
      `INSERT INTO vehicle_history (vehicle_id, driver_id, latitude, longitude, speed, altitude, heading, accuracy, address)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING *`,
      [vehicle_id, req.user.id, latitude, longitude, speed, altitude, heading, accuracy, address]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error guardando ubicación:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Obtener historial de un vehículo
app.get('/rest/v1/vehicle_history', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id, limit = 100 } = req.query;

    let query = 'SELECT * FROM vehicle_history';
    const params = [];

    if (vehicle_id) {
      params.push(vehicle_id.replace('eq.', ''));
      query += ` WHERE vehicle_id = $${params.length}`;
    }

    query += ' ORDER BY recorded_at DESC LIMIT $' + (params.length + 1);
    params.push(parseInt(limit));

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo historial:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE DOCUMENTS
// =====================================================

app.get('/rest/v1/documents', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id } = req.query;
    
    let query = 'SELECT * FROM documents WHERE is_archived = false';
    const params = [];

    if (vehicle_id) {
      params.push(vehicle_id.replace('eq.', ''));
      query += ` AND vehicle_id = $${params.length}`;
    }

    query += ' ORDER BY expiry_date ASC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo documentos:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.post('/rest/v1/documents', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id, document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes } = req.body;

    const result = await pool.query(
      `INSERT INTO documents (vehicle_id, document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [vehicle_id, document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando documento:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE TRIPS
// =====================================================

app.get('/rest/v1/trips', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id, driver_id } = req.query;
    
    let query = 'SELECT * FROM trips WHERE 1=1';
    const params = [];

    if (vehicle_id) {
      params.push(vehicle_id.replace('eq.', ''));
      query += ` AND vehicle_id = $${params.length}`;
    }

    if (driver_id) {
      params.push(driver_id.replace('eq.', ''));
      query += ` AND driver_id = $${params.length}`;
    }

    query += ' ORDER BY start_time DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo viajes:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.post('/rest/v1/trips', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id, start_latitude, start_longitude, start_address } = req.body;

    const result = await pool.query(
      `INSERT INTO trips (vehicle_id, driver_id, start_time, start_latitude, start_longitude, start_address, status)
       VALUES ($1, $2, CURRENT_TIMESTAMP, $3, $4, $5, 'in_progress')
       RETURNING *`,
      [vehicle_id, req.user.id, start_latitude, start_longitude, start_address]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando viaje:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE EXPENSES
// =====================================================

app.get('/rest/v1/expenses', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM expenses ORDER BY expense_date DESC'
    );
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo gastos:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.post('/rest/v1/expenses', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id, trip_id, expense_type, amount, description, expense_date } = req.body;

    const result = await pool.query(
      `INSERT INTO expenses (vehicle_id, trip_id, driver_id, expense_type, amount, description, expense_date)
       VALUES ($1, $2, $3, $4, $5, $6, $7)
       RETURNING *`,
      [vehicle_id, trip_id, req.user.id, expense_type, amount, description, expense_date]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando gasto:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE MAINTENANCE
// =====================================================

app.get('/rest/v1/maintenance', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id } = req.query;
    
    let query = 'SELECT * FROM maintenance WHERE 1=1';
    const params = [];

    if (vehicle_id) {
      params.push(vehicle_id.replace('eq.', ''));
      query += ` AND vehicle_id = $${params.length}`;
    }

    query += ' ORDER BY scheduled_date DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo mantenimientos:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// HEALTH CHECK
// =====================================================

app.get('/health', async (req, res) => {
  try {
    await pool.query('SELECT 1');
    res.json({ status: 'ok', database: 'connected' });
  } catch (error) {
    res.status(500).json({ status: 'error', database: 'disconnected' });
  }
});

// =====================================================
// INICIAR SERVIDOR
// =====================================================

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 PAI API corriendo en puerto ${PORT}`);
  console.log(`📦 Conectando a PostgreSQL...`);
  
  pool.query('SELECT NOW()')
    .then(() => console.log('✅ Conexión a PostgreSQL exitosa'))
    .catch(err => console.error('❌ Error conectando a PostgreSQL:', err.message));
});
