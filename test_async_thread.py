import threading
import asyncio
import time

def worker():
    print('worker started')
    async def coro():
        print('coro running')
        await asyncio.sleep(0.1)
        print('coro done')
    try:
        asyncio.run(coro())
    except Exception as e:
        print('worker exception', e)

t = threading.Thread(target=worker)
t.start()
t.join()
print('finished')