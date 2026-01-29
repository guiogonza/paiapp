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

    // PASO 1: Autenticar contra plataforma.sistemagps.online
    const gpsLoginUrl = 'https://plataforma.sistemagps.online/api/login';
    const formBody = `email=${encodeURIComponent(email)}&password=${encodeURIComponent(password)}`;
    
    console.log(`📡 Autenticando contra GPS API: ${email}`);
    
    const gpsResponse = await fetch(gpsLoginUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
        'Accept': 'application/json',
        'User-Agent': 'PAI-App/1.0'
      },
      body: formBody
    });

    const gpsData = await gpsResponse.json();
    // Log sin exponer datos sensibles
    console.log(`📡 Respuesta GPS API recibida`);

    // Verificar si la autenticación GPS fue exitosa
    if (!gpsResponse.ok || gpsData.status === 0) {
      console.log(`❌ Autenticación GPS fallida: ${gpsData.message || 'Credenciales inválidas'}`);
      return res.status(401).json({ error: 'Credenciales inválidas' });
    }

    const gpsApiKey = gpsData.user_api_hash || gpsData.api_key;
    if (!gpsApiKey) {
      console.log(`❌ No se recibió API key del GPS`);
      return res.status(401).json({ error: 'Error de autenticación GPS' });
    }

    console.log(`✅ Autenticación GPS exitosa`);

    // PASO 2: Buscar o crear usuario en base de datos local
    let result = await pool.query(
      'SELECT * FROM profiles WHERE email = $1',
      [email]
    );

    let user;
    if (result.rows.length === 0) {
      console.log(`👤 Usuario nuevo - creando perfil: ${email}`);
      
      // Crear nuevo usuario con rol 'owner' por defecto
      // Password hash no se usa porque autenticamos contra GPS
      const dummyHash = await bcrypt.hash('gps-authenticated', 10);
      
      const insertResult = await pool.query(
        `INSERT INTO profiles (email, password_hash, full_name, role, is_active, created_at) 
         VALUES ($1, $2, $3, $4, true, NOW()) 
         RETURNING *`,
        [email, dummyHash, email.split('@')[0], 'owner']
      );
      user = insertResult.rows[0];
      console.log(`✅ Usuario creado: ${user.id}`);
    } else {
      user = result.rows[0];
      
      // Actualizar última autenticación
      await pool.query(
        'UPDATE profiles SET updated_at = NOW() WHERE id = $1',
        [user.id]
      );
      console.log(`✅ Usuario existente: ${user.id}`);
    }

    // Guardar credenciales GPS en la sesión del usuario (opcional)
    await pool.query(
      `INSERT INTO user_settings (user_id, setting_key, setting_value, updated_at)
       VALUES ($1, 'gps_api_key', $2, NOW())
       ON CONFLICT (user_id, setting_key) 
       DO UPDATE SET setting_value = $2, updated_at = NOW()`,
      [user.id, gpsApiKey]
    );

    // PASO 3: Generar token JWT
    const token = jwt.sign(
      { id: user.id, email: user.email, role: user.role },
      JWT_SECRET,
      { expiresIn: '15m' }
    );

    console.log(`✅ Login exitoso: ${user.email} (${user.role})`);

    res.json({
      token: token,
      user: {
        id: user.id,
        userId: user.id, // Mantener por compatibilidad
        email: user.email,
        fullName: user.full_name,
        role: user.role,
        assignedVehicleId: user.assigned_vehicle_id,
      },
      gpsApiKey: gpsApiKey
    });
  } catch (error) {
    console.error('❌ Error en login:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// ============================================================================
// PROFILES ENDPOINTS
// ============================================================================

// Obtener perfil del usuario autenticado
app.get('/profiles/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, full_name, role, phone, assigned_vehicle_id, avatar_url, is_active, created_at, updated_at FROM profiles WHERE id = $1',
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    const profile = result.rows[0];
    res.json({
      id: profile.id,
      email: profile.email,
      fullName: profile.full_name,
      role: profile.role,
      phone: profile.phone,
      assignedVehicleId: profile.assigned_vehicle_id,
      avatarUrl: profile.avatar_url,
      isActive: profile.is_active,
      createdAt: profile.created_at,
      updatedAt: profile.updated_at
    });
  } catch (error) {
    console.error('❌ Error obteniendo perfil:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Listar todos los conductores
app.get('/profiles/drivers', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, email, full_name, phone, assigned_vehicle_id, is_active, created_at, updated_at 
       FROM profiles 
       WHERE role = 'driver' AND is_active = true
       ORDER BY full_name ASC`
    );

    const drivers = result.rows.map(driver => ({
      id: driver.id,
      email: driver.email,
      fullName: driver.full_name,
      phone: driver.phone,
      assignedVehicleId: driver.assigned_vehicle_id,
      isActive: driver.is_active,
      createdAt: driver.created_at,
      updatedAt: driver.updated_at
    }));

    res.json(drivers);
  } catch (error) {
    console.error('❌ Error listando conductores:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Crear conductor
app.post('/profiles/drivers', authenticateToken, async (req, res) => {
  try {
    const { fullName, email, phone } = req.body;

    // Generar password temporal
    const tempPassword = Math.random().toString(36).slice(-8);
    const passwordHash = await bcrypt.hash(tempPassword, 10);

    const result = await pool.query(
      `INSERT INTO profiles (email, password_hash, full_name, role, phone, is_active, created_at)
       VALUES ($1, $2, $3, 'driver', $4, true, NOW())
       RETURNING id, email, full_name, phone, is_active, created_at`,
      [email, passwordHash, fullName, phone]
    );

    const driver = result.rows[0];
    res.status(201).json({
      id: driver.id,
      email: driver.email,
      fullName: driver.full_name,
      phone: driver.phone,
      isActive: driver.is_active,
      createdAt: driver.created_at,
      temporaryPassword: tempPassword
    });
  } catch (error) {
    console.error('❌ Error creando conductor:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// ============================================================================
// VEHICLES ENDPOINTS
// ============================================================================

// Listar vehículos del usuario
app.get('/vehicles', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, placa, marca, modelo, ano, color, tipo, capacidad_carga, 
              gps_device_id, owner_id, is_active, created_at, updated_at
       FROM vehicles 
       WHERE owner_id = $1
       ORDER BY placa ASC`,
      [req.user.id]
    );

    const vehicles = result.rows.map(v => ({
      id: v.id,
      plate: v.placa,
      brand: v.marca,
      model: v.modelo,
      year: v.ano,
      color: v.color,
      type: v.tipo,
      loadCapacity: v.capacidad_carga,
      gpsDeviceId: v.gps_device_id,
      ownerId: v.owner_id,
      isActive: v.is_active,
      createdAt: v.created_at,
      updatedAt: v.updated_at
    }));

    res.json(vehicles);
  } catch (error) {
    console.error('❌ Error listando vehículos:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Crear vehículo
app.post('/vehicles', authenticateToken, async (req, res) => {
  try {
    const { plate, brand, model, year, color, type, loadCapacity, gpsDeviceId } = req.body;

    const result = await pool.query(
      `INSERT INTO vehicles (placa, marca, modelo, ano, color, tipo, capacidad_carga,
                             gps_device_id, owner_id, is_active, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, true, NOW())
       RETURNING *`,
      [plate, brand, model, year, color, type, loadCapacity, gpsDeviceId, req.user.id]
    );

    const vehicle = result.rows[0];
    res.status(201).json({
      id: vehicle.id,
      plate: vehicle.placa,
      brand: vehicle.marca,
      model: vehicle.modelo,
      year: vehicle.ano,
      color: vehicle.color,
      type: vehicle.tipo,
      loadCapacity: vehicle.capacidad_carga,
      gpsDeviceId: vehicle.gps_device_id,
      ownerId: vehicle.owner_id,
      isActive: vehicle.is_active,
      createdAt: vehicle.created_at
    });
  } catch (error) {
    console.error('❌ Error creando vehículo:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// ============================================================================
// EXPENSES ENDPOINTS
// ============================================================================

// Listar gastos
app.get('/expenses', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, driver_id, vehicle_id, trip_id, amount, expense_type, description, 
              expense_date, receipt_url, currency, created_at, updated_at
       FROM expenses 
       WHERE driver_id = $1
       ORDER BY expense_date DESC`,
      [req.user.id]
    );

    const expenses = result.rows.map(e => ({
      id: e.id,
      driverId: e.driver_id,
      vehicleId: e.vehicle_id,
      tripId: e.trip_id,
      amount: parseFloat(e.amount),
      category: e.expense_type,
      description: e.description,
      expenseDate: e.expense_date,
      receiptUrl: e.receipt_url,
      currency: e.currency,
      createdAt: e.created_at,
      updatedAt: e.updated_at
    }));

    res.json(expenses);
  } catch (error) {
    console.error('❌ Error listando gastos:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Crear gasto
app.post('/expenses', authenticateToken, async (req, res) => {
  try {
    const { vehicleId, tripId, amount, category, description, expenseDate, receiptUrl } = req.body;

    const result = await pool.query(
      `INSERT INTO expenses (driver_id, vehicle_id, trip_id, amount, expense_type, 
                            description, expense_date, receipt_url, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, NOW())
       RETURNING *`,
      [req.user.id, vehicleId, tripId, amount, category || 'otros', description, expenseDate, receiptUrl]
    );

    const expense = result.rows[0];
    res.status(201).json({
      id: expense.id,
      driverId: expense.driver_id,
      vehicleId: expense.vehicle_id,
      tripId: expense.trip_id,
      amount: parseFloat(expense.amount),
      category: expense.expense_type,
      description: expense.description,
      expenseDate: expense.expense_date,
      receiptUrl: expense.receipt_url,
      createdAt: expense.created_at
    });
  } catch (error) {
    console.error('❌ Error creando gasto:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// ============================================================================
// INCOMES ENDPOINTS
// ============================================================================

// Listar ingresos
app.get('/incomes', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, user_id, vehicle_id, trip_id, amount, source, description, 
              income_date, created_at, updated_at
       FROM incomes 
       WHERE user_id = $1
       ORDER BY income_date DESC`,
      [req.user.id]
    );

    const incomes = result.rows.map(i => ({
      id: i.id,
      userId: i.user_id,
      vehicleId: i.vehicle_id,
      tripId: i.trip_id,
      amount: parseFloat(i.amount),
      source: i.source,
      description: i.description,
      incomeDate: i.income_date,
      createdAt: i.created_at,
      updatedAt: i.updated_at
    }));

    res.json(incomes);
  } catch (error) {
    console.error('❌ Error listando ingresos:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Crear ingreso
app.post('/incomes', authenticateToken, async (req, res) => {
  try {
    const { vehicleId, tripId, amount, source, description, incomeDate } = req.body;

    const result = await pool.query(
      `INSERT INTO incomes (user_id, vehicle_id, trip_id, amount, source, 
                           description, income_date, created_at)
       VALUES ($1, $2, $3, $4, $5, $6, $7, NOW())
       RETURNING *`,
      [req.user.id, vehicleId, tripId, amount, source, description, incomeDate]
    );

    const income = result.rows[0];
    res.status(201).json({
      id: income.id,
      userId: income.user_id,
      vehicleId: income.vehicle_id,
      tripId: income.trip_id,
      amount: parseFloat(income.amount),
      source: income.source,
      description: income.description,
      incomeDate: income.income_date,
      createdAt: income.created_at
    });
  } catch (error) {
    console.error('❌ Error creando ingreso:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// ============================================================================
// TRIPS ENDPOINTS
// ============================================================================

// Listar viajes
app.get('/trips', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      `SELECT id, vehicle_id, driver_id, start_time, end_time, 
              start_address, end_address, distance_km, duration_minutes, 
              fuel_consumed, status, notes, created_at, updated_at
       FROM trips 
       WHERE driver_id = $1
       ORDER BY start_time DESC`,
      [req.user.id]
    );

    const trips = result.rows.map(t => ({
      id: t.id,
      vehicleId: t.vehicle_id,
      driverId: t.driver_id,
      startTime: t.start_time,
      endTime: t.end_time,
      startAddress: t.start_address,
      endAddress: t.end_address,
      distanceKm: t.distance_km,
      durationMinutes: t.duration_minutes,
      fuelConsumed: t.fuel_consumed,
      status: t.status,
      notes: t.notes,
      createdAt: t.created_at,
      updatedAt: t.updated_at
    }));

    res.json(trips);
  } catch (error) {
    console.error('❌ Error listando viajes:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Crear viaje
app.post('/trips', authenticateToken, async (req, res) => {
  try {
    const { vehicleId, driverId, startAddress, endAddress, status } = req.body;

    const result = await pool.query(
      `INSERT INTO trips (vehicle_id, driver_id, start_address, end_address, 
                         start_time, status, created_at)
       VALUES ($1, $2, $3, $4, NOW(), $5, NOW())
       RETURNING *`,
      [vehicleId, driverId || req.user.id, startAddress, endAddress, status || 'in_progress']
    );

    const trip = result.rows[0];
    res.status(201).json({
      id: trip.id,
      vehicleId: trip.vehicle_id,
      driverId: trip.driver_id,
      startAddress: trip.start_address,
      endAddress: trip.end_address,
      startTime: trip.start_time,
      status: trip.status,
      createdAt: trip.created_at
    });
  } catch (error) {
    console.error('❌ Error creando viaje:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Registro de nuevo usuario/conductor
app.post('/auth/signup', async (req, res) => {
  try {
    const { email, password, full_name, role = 'driver', assigned_vehicle_id } = req.body;
    
    console.log(`📝 Registrando usuario: ${email}`);
    console.log(`   - Full Name: ${full_name}`);
    console.log(`   - Role: ${role}`);
    console.log(`   - Assigned Vehicle ID: ${assigned_vehicle_id}`);
    
    // Normalizar email
    let normalizedEmail = email.trim();
    if (!normalizedEmail.includes('@')) {
      normalizedEmail = `${normalizedEmail}@conductor.app`;
    }

    console.log(`📝 Email normalizado: ${normalizedEmail}`);

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
      { expiresIn: '15m' }
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

// Alias para /auth/user (usado por el cliente Flutter)
app.get('/auth/me', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT id, email, full_name, role, assigned_vehicle_id, phone, avatar_url FROM profiles WHERE id = $1',
      [req.user.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Usuario no encontrado' });
    }

    res.json({ user: result.rows[0] });
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
    const { role, select, id, email } = req.query;
    
    let query = 'SELECT * FROM profiles WHERE is_active = true';
    const params = [];

    if (role) {
      params.push(role.replace('eq.', ''));
      query += ` AND role = $${params.length}`;
    }

    if (id) {
      params.push(id.replace('eq.', ''));
      query += ` AND id = $${params.length}`;
    }

    if (email) {
      params.push(email.replace('eq.', ''));
      query += ` AND email = $${params.length}`;
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

// Eliminar perfil/conductor
app.delete('/rest/v1/profiles/:id', authenticateToken, async (req, res) => {
  try {
    console.log(`🗑️ Eliminando perfil con ID: ${req.params.id}`);
    
    const result = await pool.query(
      'DELETE FROM profiles WHERE id = $1 RETURNING *',
      [req.params.id]
    );

    if (result.rows.length === 0) {
      console.log(`❌ Perfil no encontrado: ${req.params.id}`);
      return res.status(404).json({ error: 'Perfil no encontrado' });
    }

    console.log(`✅ Perfil eliminado: ${result.rows[0].email}`);
    res.json({ message: 'Perfil eliminado exitosamente', profile: result.rows[0] });
  } catch (error) {
    console.error('❌ Error eliminando perfil:', error);
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

// Crear vehículo (o devolver existente si la placa ya existe)
app.post('/rest/v1/vehicles', authenticateToken, async (req, res) => {
  try {
    const { placa, marca, modelo, ano, color, tipo, gps_device_id } = req.body;

    // Primero verificar si ya existe un vehículo con esa placa
    const existing = await pool.query(
      'SELECT * FROM vehicles WHERE UPPER(placa) = UPPER($1)',
      [placa]
    );

    if (existing.rows.length > 0) {
      // Ya existe, devolver el existente
      console.log(`✅ Vehículo ya existe: ${placa} (ID: ${existing.rows[0].id})`);
      return res.status(200).json(existing.rows[0]);
    }

    // No existe, crear nuevo
    const result = await pool.query(
      `INSERT INTO vehicles (placa, marca, modelo, ano, color, tipo, gps_device_id, owner_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [placa, marca, modelo, ano, color, tipo, gps_device_id, req.user.id]
    );

    console.log(`✅ Vehículo creado: ${placa} (ID: ${result.rows[0].id})`);
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
    const { vehicle_id, driver_id } = req.query;
    
    let query = 'SELECT * FROM documents WHERE is_archived = false';
    const params = [];

    if (vehicle_id) {
      params.push(vehicle_id.replace('eq.', ''));
      query += ` AND vehicle_id = $${params.length}`;
    }

    if (driver_id) {
      params.push(driver_id.replace('eq.', ''));
      query += ` AND driver_id = $${params.length}`;
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
    const { vehicle_id, driver_id, document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes, is_archived } = req.body;

    // Validar que al menos uno esté presente
    if (!vehicle_id && !driver_id) {
      return res.status(400).json({ error: 'Se requiere vehicle_id o driver_id' });
    }

    const result = await pool.query(
      `INSERT INTO documents (vehicle_id, driver_id, document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes, is_archived)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING *`,
      [vehicle_id || null, driver_id || null, document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes, is_archived || false]
    );

    console.log('✅ Documento creado:', result.rows[0]);
    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando documento:', error);
    res.status(500).json({ error: 'Error del servidor', details: error.message });
  }
});

// =====================================================
// RUTAS DE TRIPS (VIAJES)
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

app.get('/rest/v1/trips/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM trips WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Viaje no encontrado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error obteniendo viaje:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.post('/rest/v1/trips', authenticateToken, async (req, res) => {
  try {
    const { 
      vehicle_id, start_latitude, start_longitude, start_address,
      end_latitude, end_longitude, end_address, start_location, end_location,
      budget_amount, status, driver_name, client_name, revenue_amount,
      start_date, end_date
    } = req.body;

    const result = await pool.query(
      `INSERT INTO trips (vehicle_id, driver_id, start_time, start_latitude, start_longitude, 
        start_address, end_latitude, end_longitude, end_address, start_location, end_location,
        budget_amount, status, driver_name, client_name, revenue_amount, start_date, end_date)
       VALUES ($1, $2, CURRENT_TIMESTAMP, $3, $4, $5, $6, $7, $8, $9, $10, $11, COALESCE($12, 'in_progress'), $13, $14, $15, $16, $17)
       RETURNING *`,
      [vehicle_id, req.user.id, start_latitude, start_longitude, start_address,
       end_latitude, end_longitude, end_address, start_location, end_location,
       budget_amount, status, driver_name, client_name, revenue_amount, start_date, end_date]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando viaje:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.patch('/rest/v1/trips/:id', authenticateToken, async (req, res) => {
  try {
    const { 
      end_time, end_latitude, end_longitude, end_address, 
      status, total_distance, notes, end_location 
    } = req.body;

    const result = await pool.query(
      `UPDATE trips SET 
        end_time = COALESCE($1, end_time),
        end_latitude = COALESCE($2, end_latitude),
        end_longitude = COALESCE($3, end_longitude),
        end_address = COALESCE($4, end_address),
        status = COALESCE($5, status),
        total_distance = COALESCE($6, total_distance),
        notes = COALESCE($7, notes),
        end_location = COALESCE($8, end_location)
       WHERE id = $9
       RETURNING *`,
      [end_time, end_latitude, end_longitude, end_address, status, total_distance, notes, end_location, req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Viaje no encontrado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error actualizando viaje:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.delete('/rest/v1/trips/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM trips WHERE id = $1 RETURNING id', [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Viaje no encontrado' });
    }
    res.json({ message: 'Viaje eliminado' });
  } catch (error) {
    console.error('❌ Error eliminando viaje:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE EXPENSES (GASTOS)
// =====================================================

app.get('/rest/v1/expenses', authenticateToken, async (req, res) => {
  try {
    const { trip_id, driver_id, vehicle_id } = req.query;
    
    let query = 'SELECT * FROM expenses WHERE 1=1';
    const params = [];

    if (trip_id) {
      params.push(trip_id.replace('eq.', ''));
      query += ` AND trip_id = $${params.length}`;
    }
    if (driver_id) {
      params.push(driver_id.replace('eq.', ''));
      query += ` AND driver_id = $${params.length}`;
    }
    if (vehicle_id) {
      params.push(vehicle_id.replace('eq.', ''));
      query += ` AND vehicle_id = $${params.length}`;
    }

    query += ' ORDER BY expense_date DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo gastos:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.get('/rest/v1/expenses/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM expenses WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Gasto no encontrado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error obteniendo gasto:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.post('/rest/v1/expenses', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id, trip_id, expense_type, amount, description, expense_date, receipt_url, date, type, category } = req.body;
    
    // Normalizar nombres de campos
    const finalExpenseType = expense_type || type || category || 'Otro';
    const finalDate = expense_date || date || new Date().toISOString();

    const result = await pool.query(
      `INSERT INTO expenses (vehicle_id, trip_id, driver_id, expense_type, amount, description, expense_date, receipt_url)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING *`,
      [vehicle_id, trip_id, req.user.id, finalExpenseType, amount, description, finalDate, receipt_url]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando gasto:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.patch('/rest/v1/expenses/:id', authenticateToken, async (req, res) => {
  try {
    const { expense_type, amount, description, expense_date, receipt_url } = req.body;

    const result = await pool.query(
      `UPDATE expenses SET 
        expense_type = COALESCE($1, expense_type),
        amount = COALESCE($2, amount),
        description = COALESCE($3, description),
        expense_date = COALESCE($4, expense_date),
        receipt_url = COALESCE($5, receipt_url)
       WHERE id = $6
       RETURNING *`,
      [expense_type, amount, description, expense_date, receipt_url, req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Gasto no encontrado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error actualizando gasto:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.delete('/rest/v1/expenses/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM expenses WHERE id = $1 RETURNING id', [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Gasto no encontrado' });
    }
    res.json({ message: 'Gasto eliminado' });
  } catch (error) {
    console.error('❌ Error eliminando gasto:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE MAINTENANCE (MANTENIMIENTOS)
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

app.get('/rest/v1/maintenance/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('SELECT * FROM maintenance WHERE id = $1', [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Mantenimiento no encontrado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error obteniendo mantenimiento:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.post('/rest/v1/maintenance', authenticateToken, async (req, res) => {
  try {
    const { 
      vehicle_id, service_type, service_date, km_at_service, cost, 
      next_change_km, alert_date, custom_service_name, tire_position, provider_name,
      created_by
    } = req.body;

    console.log('📝 Creando mantenimiento:', { vehicle_id, service_type, km_at_service, cost });
    console.log('📝 created_by recibido del frontend:', created_by);
    console.log('📝 req.user.id del token JWT:', req.user.id);
    console.log('📝 Valor final para created_by:', created_by || req.user.id);
    
    const result = await pool.query(
      `INSERT INTO maintenance (
        vehicle_id, maintenance_type, service_date, 
        km_at_service, cost, next_maintenance_km, alert_date,
        custom_service_name, tire_position, created_by, provider_name, status
      )
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, 'completed')
       RETURNING *`,
      [
        vehicle_id, 
        service_type, 
        service_date, 
        km_at_service, 
        cost, 
        next_change_km || null,
        alert_date || null,
        custom_service_name || null,
        tire_position || null,
        created_by || req.user.id,
        provider_name || null
      ]
    );

    console.log(`✅ Mantenimiento registrado: ${result.rows[0].id}`);

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando mantenimiento:', error);
    res.status(500).json({ error: 'Error del servidor', details: error.message });
  }
});

app.patch('/rest/v1/maintenance/:id', authenticateToken, async (req, res) => {
  try {
    const { 
      service_type, service_date, km_at_service, cost, 
      next_change_km, alert_date, notes, tire_position, provider_name 
    } = req.body;

    const result = await pool.query(
      `UPDATE maintenance SET 
        maintenance_type = COALESCE($1, maintenance_type),
        service_date = COALESCE($2, service_date),
        km_at_service = COALESCE($3, km_at_service),
        cost = COALESCE($4, cost),
        next_maintenance_km = COALESCE($5, next_maintenance_km),
        alert_date = COALESCE($6, alert_date),
        notes = COALESCE($7, notes),
        tire_position = COALESCE($8, tire_position),
        provider_name = COALESCE($9, provider_name),
        updated_at = CURRENT_TIMESTAMP
       WHERE id = $10
       RETURNING *`,
      [service_type, service_date, km_at_service, cost, next_change_km, 
       alert_date, notes, tire_position, provider_name, req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Mantenimiento no encontrado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error actualizando mantenimiento:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.delete('/rest/v1/maintenance/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM maintenance WHERE id = $1 RETURNING id', [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Mantenimiento no encontrado' });
    }
    res.json({ message: 'Mantenimiento eliminado' });
  } catch (error) {
    console.error('❌ Error eliminando mantenimiento:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Limpiar alertas de mantenimiento
app.post('/rest/v1/maintenance/clear-alerts', authenticateToken, async (req, res) => {
  try {
    const { vehicle_id, service_type, exclude_id, tire_position } = req.body;

    let query = `UPDATE maintenance SET next_maintenance_km = NULL, alert_date = NULL 
                 WHERE vehicle_id = $1 AND maintenance_type = $2`;
    const params = [vehicle_id, service_type];

    if (exclude_id) {
      params.push(exclude_id);
      query += ` AND id != $${params.length}`;
    }

    if (tire_position) {
      params.push(tire_position);
      query += ` AND tire_position = $${params.length}`;
    }

    await pool.query(query, params);
    res.json({ message: 'Alertas limpiadas' });
  } catch (error) {
    console.error('❌ Error limpiando alertas:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE REMISIONES
// =====================================================

app.get('/rest/v1/remisiones', authenticateToken, async (req, res) => {
  try {
    const { trip_id, driver_id, vehicle_id, status } = req.query;
    
    let query = 'SELECT * FROM remisiones WHERE 1=1';
    const params = [];

    if (trip_id) {
      params.push(trip_id.replace('eq.', ''));
      query += ` AND trip_id = $${params.length}`;
    }
    if (driver_id) {
      params.push(driver_id.replace('eq.', ''));
      query += ` AND driver_id = $${params.length}`;
    }
    if (vehicle_id) {
      params.push(vehicle_id.replace('eq.', ''));
      query += ` AND vehicle_id = $${params.length}`;
    }
    if (status) {
      params.push(status.replace('eq.', ''));
      query += ` AND status = $${params.length}`;
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo remisiones:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.post('/rest/v1/remisiones', authenticateToken, async (req, res) => {
  try {
    const { 
      trip_id, vehicle_id, driver_id, remision_number, origin, destination,
      cargo_description, cargo_weight, delivery_date, status, notes, signature_url
    } = req.body;

    const result = await pool.query(
      `INSERT INTO remisiones (trip_id, vehicle_id, driver_id, remision_number, origin, destination,
        cargo_description, cargo_weight, delivery_date, status, notes, signature_url)
       VALUES ($1, $2, COALESCE($3, $4), $5, $6, $7, $8, $9, $10, COALESCE($11, 'pending'), $12, $13)
       RETURNING *`,
      [trip_id, vehicle_id, driver_id || req.user.id, req.user.id, remision_number, origin, destination,
       cargo_description, cargo_weight, delivery_date, status, notes, signature_url]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error creando remisión:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.patch('/rest/v1/remisiones/:id', authenticateToken, async (req, res) => {
  try {
    const { status, signature_url, delivery_date, notes } = req.body;

    const result = await pool.query(
      `UPDATE remisiones SET 
        status = COALESCE($1, status),
        signature_url = COALESCE($2, signature_url),
        delivery_date = COALESCE($3, delivery_date),
        notes = COALESCE($4, notes)
       WHERE id = $5
       RETURNING *`,
      [status, signature_url, delivery_date, notes, req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Remisión no encontrada' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error actualizando remisión:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Actualizar vehículo (soporta UUID o GPS device ID)
app.patch('/rest/v1/vehicles/:id', authenticateToken, async (req, res) => {
  try {
    const { placa, marca, modelo, ano, color, tipo, gps_device_id, current_mileage, is_active } = req.body;
    const vehicleId = req.params.id;
    
    // Verificar si es un UUID válido o un ID numérico (GPS)
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(vehicleId);
    const whereClause = isUuid ? 'id = $10' : 'gps_device_id = $10';

    const result = await pool.query(
      `UPDATE vehicles SET 
        placa = COALESCE($1, placa),
        marca = COALESCE($2, marca),
        modelo = COALESCE($3, modelo),
        ano = COALESCE($4, ano),
        color = COALESCE($5, color),
        tipo = COALESCE($6, tipo),
        gps_device_id = COALESCE($7, gps_device_id),
        current_mileage = COALESCE($8, current_mileage),
        is_active = COALESCE($9, is_active)
       WHERE ${whereClause}
       RETURNING *`,
      [placa, marca, modelo, ano, color, tipo, gps_device_id, current_mileage, is_active, vehicleId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Vehículo no encontrado' });
    }
    console.log(`✅ Vehículo actualizado: ${result.rows[0].placa} (ID: ${result.rows[0].id})`);
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error actualizando vehículo:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Obtener vehículo por ID (soporta UUID o GPS device ID)
app.get('/rest/v1/vehicles/:id', authenticateToken, async (req, res) => {
  try {
    const vehicleId = req.params.id;
    
    // Verificar si es un UUID válido o un ID numérico (GPS)
    const isUuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(vehicleId);
    
    let result;
    if (isUuid) {
      result = await pool.query('SELECT * FROM vehicles WHERE id = $1', [vehicleId]);
    } else {
      // Buscar por gps_device_id si no es UUID
      result = await pool.query('SELECT * FROM vehicles WHERE gps_device_id = $1', [vehicleId]);
    }
    
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Vehículo no encontrado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error obteniendo vehículo:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Eliminar vehículo (soft delete)
app.delete('/rest/v1/vehicles/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'UPDATE vehicles SET is_active = false WHERE id = $1 RETURNING id',
      [req.params.id]
    );
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Vehículo no encontrado' });
    }
    res.json({ message: 'Vehículo eliminado' });
  } catch (error) {
    console.error('❌ Error eliminando vehículo:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// Actualizar documento
app.patch('/rest/v1/documents/:id', authenticateToken, async (req, res) => {
  try {
    const { document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes, is_archived } = req.body;

    const result = await pool.query(
      `UPDATE documents SET 
        document_type = COALESCE($1, document_type),
        document_number = COALESCE($2, document_number),
        issue_date = COALESCE($3, issue_date),
        expiry_date = COALESCE($4, expiry_date),
        alert_date = COALESCE($5, alert_date),
        document_url = COALESCE($6, document_url),
        notes = COALESCE($7, notes),
        is_archived = COALESCE($8, is_archived)
       WHERE id = $9
       RETURNING *`,
      [document_type, document_number, issue_date, expiry_date, alert_date, document_url, notes, is_archived, req.params.id]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Documento no encontrado' });
    }
    res.json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error actualizando documento:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.delete('/rest/v1/documents/:id', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query('DELETE FROM documents WHERE id = $1 RETURNING id', [req.params.id]);
    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Documento no encontrado' });
    }
    res.json({ message: 'Documento eliminado' });
  } catch (error) {
    console.error('❌ Error eliminando documento:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

// =====================================================
// RUTAS DE GPS CREDENTIALS
// =====================================================

app.get('/rest/v1/gps_credentials', authenticateToken, async (req, res) => {
  try {
    const result = await pool.query(
      'SELECT * FROM gps_credentials WHERE user_id = $1 ORDER BY created_at DESC LIMIT 1',
      [req.user.id]
    );
    res.json(result.rows);
  } catch (error) {
    console.error('❌ Error obteniendo credenciales GPS:', error);
    res.status(500).json({ error: 'Error del servidor' });
  }
});

app.post('/rest/v1/gps_credentials', authenticateToken, async (req, res) => {
  try {
    const { provider, email, password } = req.body;

    // Upsert - actualizar si ya existe para este usuario y proveedor
    const result = await pool.query(
      `INSERT INTO gps_credentials (user_id, provider, email, password)
       VALUES ($1, $2, $3, $4)
       ON CONFLICT (user_id, provider) DO UPDATE SET 
         email = EXCLUDED.email, 
         password = EXCLUDED.password, 
         updated_at = CURRENT_TIMESTAMP
       RETURNING *`,
      [req.user.id, provider || 'sistemagps', email, password]
    );

    res.status(201).json(result.rows[0]);
  } catch (error) {
    console.error('❌ Error guardando credenciales GPS:', error);
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
