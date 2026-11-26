defmodule FirmowidWeb.Inventory.Views.EquipmentList do
  @moduledoc "The company's equipment with who holds each piece, narrowed to the available or the issued."

  use FirmowidWeb, :live_view

  import FirmowidUI.Components.Link
  import FirmowidWeb.Inventory.Components.Equipment
  import Phoenix.Component, except: [link: 1]

  alias Firmowid.Inventory
  alias FirmowidWeb.Inventory.Utilities.Navigation

  on_mount {FirmowidWeb.Infrastructure.Hooks.RequireAdmin, :default}

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, :page_title, pgettext("sidebar", "Equipment"))}
  end

  @impl true
  def handle_params(params, _uri, socket) do
    scope = socket.assigns.ash_scope
    status = Navigation.parse_status(params)
    equipment = Inventory.list_equipment!(%{status: status}, scope: scope)

    zero_state? =
      equipment == [] and (is_nil(status) or Inventory.list_equipment!(%{}, scope: scope) == [])

    {:noreply,
     socket
     |> assign(:status, status)
     |> assign(:equipment, equipment)
     |> assign(:zero_state?, zero_state?)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="flex w-full flex-col gap-6 px-4 py-6 md:px-10 md:pt-8 md:pb-12">
      <header class="flex items-end justify-between gap-4">
        <h1 class="text-3xl/[1.3] font-bold text-grey-900">{pgettext("sidebar", "Equipment")}</h1>
        <.page_actions>
          <:action>
            <.link navigate={Navigation.new_path()} kind="button" variant="special" data-fab>
              <.icon name="hero-plus-mini" class="size-6" />
              <span class="max-md:sr-only">{gettext("Add equipment")}</span>
            </.link>
          </:action>
        </.page_actions>
      </header>

      <.filter_pills :if={not @zero_state?}>
        <:pill patch={Navigation.list_path()} active={is_nil(@status)}>
          {pgettext("equipment filter", "All")}
        </:pill>
        <:pill patch={Navigation.list_path(:available)} active={@status == :available}>
          {pgettext("equipment filter", "Available")}
        </:pill>
        <:pill patch={Navigation.list_path(:issued)} active={@status == :issued}>
          {pgettext("equipment filter", "Issued")}
        </:pill>
      </.filter_pills>

      <.empty_state
        :if={@equipment == []}
        size="small"
        title={
          if @zero_state?,
            do: gettext("You have no equipment yet"),
            else: gettext("No equipment matches the filter.")
        }
        class="py-16!"
      >
        <:icon><Lucideicons.laptop class="text-grey-400" /></:icon>
        <p :if={@zero_state?} class="text-sm/[1.35] text-grey-600">
          {gettext("Add laptops, phones and other equipment to know who holds them and since when.")}
        </p>
      </.empty_state>

      <div
        :if={@equipment != []}
        id="equipment-list"
        class="grid grid-cols-[minmax(0,1fr)_8rem_12rem_minmax(0,16rem)_min-content] gap-x-6 gap-y-2 max-md:grid-cols-[minmax(0,1fr)_min-content]"
      >
        <div class="col-span-full grid grid-cols-subgrid px-4 py-1 text-sm/[1.35] text-grey-500">
          <p>{gettext("Name")}</p>
          <p class="max-md:hidden">{gettext("Kind")}</p>
          <p class="max-md:hidden">{gettext("Serial number")}</p>
          <p class="max-md:hidden">{gettext("Held by")}</p>
          <span />
        </div>

        <.link
          :for={equipment <- @equipment}
          :key={equipment.id}
          kind="unstyled"
          navigate={Navigation.equipment_path(equipment.id)}
          class="col-span-full grid grid-cols-subgrid items-center rounded-sm bg-white px-4 text-grey-900 hover:bg-grey-50 max-md:py-3 md:h-[57px]"
        >
          <div class="min-w-0">
            <p class="truncate text-base/[1.35]">{equipment.name}</p>
            <div class="mt-1 md:hidden"><.holder assignment={equipment.current_assignment} /></div>
          </div>
          <p class="text-sm/[1.35] text-grey-700 max-md:hidden">{kind_label(equipment.kind)}</p>
          <p class="truncate text-sm/[1.35] text-grey-700 max-md:hidden">
            {equipment.serial_number || "–"}
          </p>
          <div class="min-w-0 truncate max-md:hidden">
            <.holder assignment={equipment.current_assignment} />
          </div>
          <Lucideicons.chevron_right class="size-4 shrink-0 text-black" />
        </.link>
      </div>
    </div>
    """
  end
end
