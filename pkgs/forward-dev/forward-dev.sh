PORT="${1:-3000}"
DOMAIN="dev.ryannavsaria.co.uk"
TUNNEL_NAME="dev-tunnel"

echo "Forwarding https://$DOMAIN --> http://127.0.0.1:$PORT"
echo "Press Ctrl+C to stop forwarding."

cloudflared tunnel --url "http://localhost:$PORT" run "$TUNNEL_NAME"
