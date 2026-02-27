# pip install websockets
import asyncio, websockets, json

clients = set()

async def handler(ws):
    clients.add(ws)
    try:
        async for msg in ws:
            for c in list(clients):
                if c != ws:
                    try:
                        await c.send(msg)
                    except:
                        pass
    finally:
        clients.discard(ws)

async def main():
    async with websockets.serve(handler, "", 8765):
        print("WebSocket relay at ws://0.0.0.0:8765")
        await asyncio.Future()

if __name__ == "__main__":
    asyncio.run(main())
