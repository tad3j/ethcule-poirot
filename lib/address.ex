defmodule Address do
  @moduledoc false

  defstruct [:eth_address, :contract, :transactions, :end_cursor, :has_next_page]

  @type t :: %__MODULE__{
          eth_address: String.t() | nil,
          contract: boolean() | nil,
          transactions: list(Transaction.t()) | nil,
          end_cursor: String.t() | nil,
          has_next_page: boolean() | nil,
        }
end
