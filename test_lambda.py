# Test capturing exception variable in lambda

# Case A: capture exception var directly
try:
    raise RuntimeError('boom')
except Exception as e:
    f = lambda: print(f'Error A: {e}')

try:
    f()
except Exception as ex:
    print('Case A raised:', type(ex), ex)

# Case B: capture message into default arg
try:
    raise RuntimeError('boom2')
except Exception as e:
    msg = f'Error B: {e}'
    g = lambda msg=msg: print(msg)

try:
    g()
except Exception as ex:
    print('Case B raised:', type(ex), ex)
