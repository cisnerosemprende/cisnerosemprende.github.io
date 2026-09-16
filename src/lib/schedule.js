// =========================================================================
// Helper de Horarios y Cálculo Abierto/Cerrado (Zona Horaria Colombia)
// =========================================================================

const DIAS_SEMANA = ['domingo', 'lunes', 'martes', 'miercoles', 'jueves', 'viernes', 'sabado'];

/**
 * Obtiene la hora actual y día de la semana en la zona horaria de Colombia (America/Bogota)
 */
export function getColombiaCurrentTime() {
  const now = new Date();
  
  // Convertir a string con formato de Colombia
  const options = { timeZone: 'America/Bogota', hour12: false };
  const formatter = new Intl.DateTimeFormat('es-CO', {
    ...options,
    weekday: 'long',
    hour: '2-digit',
    minute: '2-digit'
  });

  const parts = formatter.formatToParts(now);
  let weekdayStr = '';
  let hour = 0;
  let minute = 0;

  parts.forEach(p => {
    if (p.type === 'weekday') weekdayStr = p.value.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
    if (p.type === 'hour') hour = parseInt(p.value, 10);
    if (p.type === 'minute') minute = parseInt(p.value, 10);
  });

  // Fallback a índice si normalize fallase
  const dayIndex = now.getDay();
  const normalizedDay = DIAS_SEMANA[dayIndex];

  return {
    dayName: weekdayStr || normalizedDay,
    currentMinutes: (hour * 60) + minute,
    timeString: `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`
  };
}

/**
 * Convierte "HH:MM" a minutos del día
 */
function parseTimeToMinutes(timeStr) {
  if (!timeStr) return 0;
  const [h, m] = timeStr.split(':').map(Number);
  return (h * 60) + (m || 0);
}

/**
 * Evalúa el estado de atención de un negocio
 * @param {Object} schedule - Objeto JSONB con horarios
 * @returns {Object} { isOpen: boolean, label: string, detail: string, badgeColor: string }
 */
export function checkBusinessOpenStatus(schedule) {
  if (!schedule || typeof schedule !== 'object' || Object.keys(schedule).length === 0) {
    return {
      isOpen: false,
      label: 'Consultar Horario',
      detail: 'Horario no especificado',
      badgeColor: 'bg-slate-100 text-slate-700 border-slate-300'
    };
  }

  const { dayName, currentMinutes } = getColombiaCurrentTime();
  const daySchedule = schedule[dayName];

  if (!daySchedule || daySchedule.closed) {
    return {
      isOpen: false,
      label: 'Cerrado hoy',
      detail: `No abre los ${dayName}s`,
      badgeColor: 'bg-red-50 text-red-700 border-red-200'
    };
  }

  const openMinutes = parseTimeToMinutes(daySchedule.open);
  const closeMinutes = parseTimeToMinutes(daySchedule.close);

  // Manejo de horarios que cruzan la medianoche (ej: abre 18:00 y cierra 02:00)
  let isOpenNow = false;
  if (closeMinutes > openMinutes) {
    isOpenNow = currentMinutes >= openMinutes && currentMinutes < closeMinutes;
  } else {
    // Cruza medianoche
    isOpenNow = currentMinutes >= openMinutes || currentMinutes < closeMinutes;
  }

  if (isOpenNow) {
    // Si falta menos de 45 minutos para cerrar
    const diff = closeMinutes - currentMinutes;
    if (diff > 0 && diff <= 45) {
      return {
        isOpen: true,
        label: 'Cierra pronto',
        detail: `Cierra a las ${daySchedule.close}`,
        badgeColor: 'bg-amber-50 text-amber-800 border-amber-300 animate-pulse'
      };
    }

    return {
      isOpen: true,
      label: 'Abierto ahora',
      detail: `Hoy hasta las ${daySchedule.close}`,
      badgeColor: 'bg-emerald-50 text-emerald-800 border-emerald-300'
    };
  } else {
    if (currentMinutes < openMinutes) {
      return {
        isOpen: false,
        label: 'Cerrado ahora',
        detail: `Abre hoy a las ${daySchedule.open}`,
        badgeColor: 'bg-rose-50 text-rose-700 border-rose-200'
      };
    } else {
      return {
        isOpen: false,
        label: 'Cerrado ahora',
        detail: `Cerró a las ${daySchedule.close}`,
        badgeColor: 'bg-slate-100 text-slate-700 border-slate-300'
      };
    }
  }
}
