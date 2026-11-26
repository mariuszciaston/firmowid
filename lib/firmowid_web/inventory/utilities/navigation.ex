defmodule FirmowidWeb.Inventory.Utilities.Navigation do
  @moduledoc "URL contract of the equipment inventory: the list with its status filter and the pages of each equipment."

  use FirmowidWeb, :verified_routes

  alias FirmowidWeb.Infrastructure.Utilities.PolishValues

  @status_values %{"dostepne" => :available, "wydane" => :issued}
  @status_params %{available: "dostepne", issued: "wydane"}

  @doc "The equipment list, optionally narrowed to the available or the issued equipment."
  @spec list_path(:available | :issued | nil) :: String.t()
  def list_path(status \\ nil)
  def list_path(nil), do: ~p"/zarzadzanie/sprzet"

  def list_path(status), do: ~p"/zarzadzanie/sprzet?#{[filtr: PolishValues.encode_atom(status, @status_params)]}"

  @doc "Parses the `filtr` query value of the equipment list."
  @spec parse_status(map()) :: :available | :issued | nil
  def parse_status(params), do: PolishValues.parse_atom(params["filtr"], @status_values)

  @doc "The page that adds equipment."
  @spec new_path() :: String.t()
  def new_path, do: ~p"/zarzadzanie/sprzet/dodaj"

  @doc "The page of one equipment with its history."
  @spec equipment_path(String.t()) :: String.t()
  def equipment_path(id), do: ~p"/zarzadzanie/sprzet/#{id}"

  @doc "The page that edits one equipment."
  @spec edit_path(String.t()) :: String.t()
  def edit_path(id), do: ~p"/zarzadzanie/sprzet/#{id}/edycja"
end
