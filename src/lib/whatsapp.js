// =========================================================================
// Generador del Mini-Carro para WhatsApp (wa.me)
// Formateo de orden, cálculo de totales y dirección escrita para Cisneros
// =========================================================================

/**
 * Formatea un número a pesos colombianos (COP)
 */
export function formatCurrencyCOP(value) {
  return new Intl.NumberFormat('es-CO', {
    style: 'currency',
    currency: 'COP',
    maximumFractionDigits: 0
  }).format(Number(value) || 0);
}

/**
 * Genera el enlace wa.me completamente estructurado
 * @param {Object} business - Datos del negocio
 * @param {Array} cart - Artículos en carrito [{ id, name, price, quantity }]
 * @param {Object} deliveryInfo - { address, reference, paymentMethod, customerName, notes }
 * @returns {string} Enlace listo para abrir WhatsApp
 */
export function buildWhatsAppOrderLink(business, cart, deliveryInfo = {}) {
  if (!business || !business.whatsapp_number) return '#';
  if (!cart || cart.length === 0) return '#';

  // Normalización del número a estándar internacional
  let phone = String(business.whatsapp_number).replace(/\D/g, '');
  if (!phone.startsWith('57')) {
    phone = '57' + phone;
  }

  // Cálculos económicos
  const subtotal = cart.reduce((sum, item) => sum + (Number(item.price) * Number(item.quantity)), 0);
  const deliveryCost = business.delivery_available ? Number(business.delivery_cost || 0) : 0;
  const total = subtotal + deliveryCost;

  // Construcción del texto
  let text = `👋 *¡Hola, ${business.name}!* \n`;
  text += `He armado este pedido desde la plataforma *Cisneros Emprende*:\n\n`;
  
  text += `🛍️ *MI PEDIDO:*\n`;
  cart.forEach(item => {
    const itemSubtotal = Number(item.price) * Number(item.quantity);
    text += `• *${item.quantity}x* ${item.name} (${formatCurrencyCOP(itemSubtotal)})\n`;
  });

  text += `\n💰 *VALOR A PAGAR:*\n`;
  text += `• Subtotal productos: ${formatCurrencyCOP(subtotal)}\n`;
  if (business.delivery_available) {
    text += `• Domicilio: ${deliveryCost === 0 ? '¡Gratis en el casco urbano!' : formatCurrencyCOP(deliveryCost)}\n`;
  } else {
    text += `• Entrega: Para recoger en el local\n`;
  }
  text += `👉 *TOTAL FINAL: ${formatCurrencyCOP(total)}*\n\n`;

  text += `📍 *DATOS DE ENTREGA (CISNEROS):*\n`;
  text += `• *Dirección:* ${deliveryInfo.address || 'Para acordar por chat'}\n`;
  if (deliveryInfo.reference) {
    text += `• *Punto de referencia:* ${deliveryInfo.reference}\n`;
  }
  text += `• *Forma de pago:* ${deliveryInfo.paymentMethod || 'Efectivo contra entrega'}\n`;
  if (deliveryInfo.customerName) {
    text += `• *Cliente:* ${deliveryInfo.customerName}\n`;
  }
  if (deliveryInfo.notes) {
    text += `• *Notas adicionales:* ${deliveryInfo.notes}\n`;
  }

  text += `\n_¿Tienen disponibilidad para procesar este pedido ahora? Muchas gracias._`;

  return `https://wa.me/${phone}?text=${encodeURIComponent(text)}`;
}
