defmodule EthculePoirot.AddressExplorer do
  @moduledoc false
  require Logger
  use GenServer, restart: :transient

  alias EthculePoirot.NetworkExplorer

  @spec start_link(%{
          eth_address: String.t(),
          depth: pos_integer(),
          api_handler: atom()
        }) ::
          {:ok, pid()}
  def start_link(%{eth_address: eth_address} = initial_state) do
    {:ok, pid} = GenServer.start_link(__MODULE__, initial_state)

    Logger.info("Querying #{eth_address}")
    send(pid, :start)

    {:ok, pid}
  end

  @impl true
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl true
  def handle_info(:start, %{depth: 0} = state) do
    address_information = state.api_handler.address_information(state.eth_address)
    update_node_label(address_information.contract, state.eth_address)

    NetworkExplorer.node_visited(state.eth_address)

    {:stop, :normal, state}
  end

  @impl true
 def handle_info(:start, %{depth: depth} = state) do
    search_after = nil
    handle_info_loop(state, depth, search_after)
    NetworkExplorer.node_visited(state.eth_address)
    {:stop, :normal, state}
  end

  defp handle_info_loop(state, depth, search_after) do
    state.eth_address
    |> state.api_handler.transactions_for_address(search_after)
    |> handle_transactions(depth)
    |> handle_next_page(state, depth, search_after)
  end

  @spec handle_next_page(Address.t(), any(), pos_integer(), String.t()) :: any()
  defp handle_next_page(address_info, state, depth, search_after) do
    if address_info.has_next_page do
      state
      |> handle_info_loop(depth, address_info.end_cursor)
    else
      Logger.debug("Last page for #{address_info.eth_address} reached (after #{search_after})")
    end
  end

  @spec handle_transactions(Address.t(), pos_integer()) :: Address.t()
  defp handle_transactions(%{transactions: []} = address_info, _depth) do
    update_node_label(address_info.contract, address_info.eth_address)
    address_info
  end

  defp handle_transactions(address_info, depth) do
    Enum.each(address_info.transactions, fn trx ->
      next_address =
        Neo4j.Client.transaction_relation(
          address_info,
          trx
        )

      NetworkExplorer.visit_node(next_address, depth - 1)
    end)
    address_info
  end

  @spec update_node_label(true, String.t()) :: any()
  defp update_node_label(contract_code, eth_address) when contract_code do
    Neo4j.Client.set_node_label(eth_address, "SmartContract")
  end

  @spec update_node_label(nil | false, String.t()) :: any()
  defp update_node_label(_contract, eth_address) do
    Neo4j.Client.set_node_label(eth_address, "Account")
  end
end
