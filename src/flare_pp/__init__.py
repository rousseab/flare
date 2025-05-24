try:
    from ._C_flare import SparseGP, Structure, NormalizedDotProduct, B2, DotProduct
except Exception as e:
    raise ModuleNotFoundError(f"Cannot import _C_flare: {e.__class__.__name__}: {e}")
