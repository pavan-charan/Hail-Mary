import qrcode
import io
import base64

def generate_qr_base64_image(facility_id: str) -> str:
    """
    Generates a high-contrast QR code PNG containing ONLY the Facility ID as per requirement.
    Returns base64 encoded PNG.
    """
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_H,
        box_size=10,
        border=4,
    )
    # Payload contains strictly the Facility ID
    qr.add_data(facility_id)
    qr.make(fit=True)

    img = qr.make_image(fill_color="black", back_color="white")
    buffered = io.BytesIO()
    img.save(buffered, format="PNG")
    return base64.b64encode(buffered.getvalue()).decode("utf-8")
