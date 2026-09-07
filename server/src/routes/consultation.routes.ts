import { Router, Request, Response } from 'express';

const router = Router();

export interface ConsultationSession {
  appointmentId: string;
  roomId: string;
  callUrl: string;
  customMessage?: string;
  patient: {
    id: string;
    name: string;
    phone: string;
    gender: string;
    bloodGroup: string;
    condition: string;
    symptoms: string;
  };
  doctor: {
    id: string;
    name: string;
    specialty: string;
  };
  appointment: {
    date: string;
    time: string;
    type: string;
    status: 'scheduled' | 'inProgress' | 'completed' | 'cancelled';
  };
  sharedAt: string;
  updatedAt: string;
  endedAt?: string;
}

// In-memory store for active consultations (keyed by appointmentId and roomId)
const activeConsultations = new Map<string, ConsultationSession>();
const roomToAppointmentMap = new Map<string, string>();

// Preload clinical sample patient for seamless Prachtiz integration demo
const DEFAULT_PATIENT = {
  id: '8eb84baf-7a92-474b-911b-a0d11c3728d7',
  name: 'Priya Sharma',
  phone: '+91 76543 21098',
  gender: 'Female',
  bloodGroup: 'B+',
  condition: 'Type 2 Diabetes',
  symptoms: 'Headache and Dizziness',
};

const DEFAULT_DOCTOR = {
  id: 'af5b6e04-7bc7-45d6-903d-3945c63663fc',
  name: 'Dr. Amanulla Baig',
  specialty: 'General Physician',
};

/**
 * 🟢 Endpoint 1: Share Generated Room Link to Patient Portal
 * Method: POST /api/consultation/call/share
 */
router.post('/call/share', (req: Request, res: Response) => {
  try {
    const {
      appointment_id,
      call_url,
      room_id,
      custom_message,
      patient_name,
      patient_symptoms,
      patient_id,
      doctor_name,
      doctor_id,
      specialty,
      date,
      time,
    } = req.body;

    const appointmentId = appointment_id || req.body.appointmentId || '4eb2eeed-35f7-4919-ae74-6632c048bcce';
    const roomId = room_id || req.body.roomId || `room-${Date.now()}`;
    const callUrl = call_url || req.body.callUrl || `https://audio-video-calling.vercel.app/room/${roomId}`;
    const message = custom_message || `Dr. Amanulla Baig has started your video consultation. Click below to join.`;

    const patientName = patient_name || req.body.patientName || DEFAULT_PATIENT.name;
    const symptoms = patient_symptoms || req.body.symptoms || DEFAULT_PATIENT.symptoms;

    const session: ConsultationSession = {
      appointmentId,
      roomId,
      callUrl,
      customMessage: message,
      patient: {
        id: patient_id || DEFAULT_PATIENT.id,
        name: patientName,
        phone: DEFAULT_PATIENT.phone,
        gender: DEFAULT_PATIENT.gender,
        bloodGroup: DEFAULT_PATIENT.bloodGroup,
        condition: DEFAULT_PATIENT.condition,
        symptoms: symptoms,
      },
      doctor: {
        id: doctor_id || DEFAULT_DOCTOR.id,
        name: doctor_name || DEFAULT_DOCTOR.name,
        specialty: specialty || DEFAULT_DOCTOR.specialty,
      },
      appointment: {
        date: date || '2026-09-07',
        time: time || '10:30',
        type: 'Consultation',
        status: 'inProgress',
      },
      sharedAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
    };

    activeConsultations.set(appointmentId, session);
    roomToAppointmentMap.set(roomId, appointmentId);

    console.log(`[PrachtizAPI] ✅ Call invitation shared for appointment ${appointmentId} in room ${roomId}`);

    return res.status(200).json({
      success: true,
      shared: true,
      appointmentId: session.appointmentId,
      callUrl: session.callUrl,
      roomId: session.roomId,
      patientData: {
        name: session.patient.name,
        symptoms: session.patient.symptoms,
      },
      message: 'Call invitation shared directly with the patient in the portal.',
    });
  } catch (err: any) {
    console.error('[PrachtizAPI] ❌ Error in /call/share:', err);
    return res.status(500).json({ success: false, error: err.message || 'Internal Server Error' });
  }
});

/**
 * 🟢 Endpoint 2: Fetch Full Patient & Booking Details
 * Method: GET /api/consultation/appointment-data/:appointmentId
 */
router.get('/appointment-data/:appointmentId', (req: Request, res: Response) => {
  try {
    const { appointmentId } = req.params;

    const session = activeConsultations.get(appointmentId);

    if (session) {
      return res.status(200).json({
        success: true,
        appointmentId: session.appointmentId,
        patient: session.patient,
        doctor: session.doctor,
        appointment: session.appointment,
      });
    }

    // Default mock response matching Prachtiz integration specification
    return res.status(200).json({
      success: true,
      appointmentId,
      patient: DEFAULT_PATIENT,
      doctor: DEFAULT_DOCTOR,
      appointment: {
        date: '2026-09-07',
        time: '10:30',
        type: 'Consultation',
        status: 'inProgress',
      },
    });
  } catch (err: any) {
    console.error('[PrachtizAPI] ❌ Error in /appointment-data:', err);
    return res.status(500).json({ success: false, error: err.message || 'Internal Server Error' });
  }
});

/**
 * 🟢 Endpoint 3: End Call & Mark Appointment Completed
 * Method: POST /api/consultation/call/:roomId/end
 */
router.post('/call/:roomId/end', (req: Request, res: Response) => {
  try {
    const { roomId } = req.params;
    const { appointment_id } = req.body;

    const appointmentId = appointment_id || req.body.appointmentId || roomToAppointmentMap.get(roomId);

    if (appointmentId && activeConsultations.has(appointmentId)) {
      const session = activeConsultations.get(appointmentId)!;
      session.appointment.status = 'completed';
      session.endedAt = new Date().toISOString();
      session.updatedAt = new Date().toISOString();
      activeConsultations.set(appointmentId, session);
    }

    console.log(`[PrachtizAPI] 🛑 Call session ended for room ${roomId} (appointment: ${appointmentId || 'unknown'})`);

    return res.status(200).json({
      success: true,
      ended: true,
      message: 'Call session ended and appointment marked completed',
    });
  } catch (err: any) {
    console.error('[PrachtizAPI] ❌ Error in /call/:roomId/end:', err);
    return res.status(500).json({ success: false, error: err.message || 'Internal Server Error' });
  }
});

/**
 * 🟢 Real-Time Polling Helper: Check active call status for Patient Portal
 * Method: GET /api/consultation/call/:appointmentId/status
 */
router.get('/call/:appointmentId/status', (req: Request, res: Response) => {
  const { appointmentId } = req.params;
  const session = activeConsultations.get(appointmentId);

  if (!session) {
    return res.status(200).json({
      success: true,
      hasActiveCall: false,
      appointmentId,
      status: 'scheduled',
      message: 'No live call has started for this appointment yet.',
    });
  }

  return res.status(200).json({
    success: true,
    hasActiveCall: session.appointment.status === 'inProgress',
    appointmentId: session.appointmentId,
    roomId: session.roomId,
    callUrl: session.callUrl,
    customMessage: session.customMessage,
    patientData: {
      name: session.patient.name,
      symptoms: session.patient.symptoms,
    },
    doctorData: session.doctor,
    status: session.appointment.status,
    sharedAt: session.sharedAt,
  });
});

/**
 * 🟢 List all active consultations
 * Method: GET /api/consultation/active
 */
router.get('/active', (_req: Request, res: Response) => {
  const sessions = Array.from(activeConsultations.values());
  return res.status(200).json({
    success: true,
    count: sessions.length,
    consultations: sessions,
  });
});

export default router;
