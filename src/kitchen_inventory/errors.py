"""Domain errors. Failures are exceptions, never None."""


class KitchenInventoryError(Exception):
    """Base for all kitchen_inventory errors."""


class InvalidState(KitchenInventoryError):
    """Server gate, lock wait/deadlock, illegal transition, missing lookup code."""


class InsufficientQty(KitchenInventoryError):
    """On-hand cannot cover demand after FIFO allocation."""


class ConversionError(KitchenInventoryError):
    """Missing or impossible unit conversion (fail closed)."""

    def __init__(
        self,
        message: str,
        *,
        item_id: int | None = None,
        from_unit: str | None = None,
        to_unit: str | None = None,
        lot_id: int | None = None,
    ) -> None:
        super().__init__(message)
        self.item_id = item_id
        self.from_unit = from_unit
        self.to_unit = to_unit
        self.lot_id = lot_id
