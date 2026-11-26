defmodule FirmowidWeb.Inventory.Views.EquipmentForm do
  @moduledoc "Adds equipment to the inventory or edits its name, kind and serial number."

  use FirmowidWeb, :live_view

  import FirmowidUI.Components.Button
  import FirmowidUI.Components.Link
  import FirmowidWeb.Inventory.Components.Equipment, only: [kind_label: 1]
  import Phoenix.Component, except: [link: 1]

  alias Firmowid.Inventory
  alias Firmowid.Inventory.Equipment
  alias FirmowidWeb.Inventory.Utilities.Navigation

  on_mount {FirmowidWeb.Infrastructure.Hooks.RequireAdmin, :default}

  @impl true
  def mount(_params, _session, %{assigns: %{live_action: :new}} = socket) do
    form =
      AshPhoenix.Form.for_create(Equipment, :create,
        scope: socket.assigns.ash_scope,
        as: "equipment"
      )

    {:ok, assign_form(socket, nil, form)}
  end

  def mount(%{"id" => id}, _session, %{assigns: %{live_action: :edit}} = socket) do
    scope = socket.assigns.ash_scope

    case Inventory.get_equipment(id, scope: scope, not_found_error?: false) do
      {:ok, nil} ->
        {:ok, push_navigate(socket, to: Navigation.list_path())}

      {:ok, equipment} ->
        form = AshPhoenix.Form.for_update(equipment, :update, scope: scope, as: "equipment")
        {:ok, assign_form(socket, equipment, form)}
    end
  end

  @impl true
  def handle_event("validate", %{"equipment" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"equipment" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, equipment} ->
        {:noreply, push_navigate(socket, to: Navigation.equipment_path(equipment.id))}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(socket, equipment, form) do
    socket
    |> assign(:equipment, equipment)
    |> assign(:form, form)
    |> assign(
      :page_title,
      if(equipment, do: gettext("Edit equipment"), else: gettext("New equipment"))
    )
  end

  @impl true
  def render(assigns) do
    assigns =
      assign(assigns,
        form: to_form(assigns.form),
        kind_options: Enum.map(Equipment.kinds(), &{kind_label(&1), &1}),
        cancel_path:
          if(assigns.equipment,
            do: Navigation.equipment_path(assigns.equipment.id),
            else: Navigation.list_path()
          )
      )

    ~H"""
    <div class="mx-auto flex w-full max-w-7xl flex-1 flex-col gap-8 pt-4">
      <.form
        for={@form}
        id="equipment-form"
        phx-change="validate"
        phx-submit="save"
        class="flex flex-col gap-8"
      >
        <div class="flex flex-row items-start justify-between">
          <div class="space-y-1">
            <p :if={@equipment} class="text-sm/snug text-grey-500">{@equipment.name}</p>
            <p class="text-2xl/tight font-medium">{@page_title}</p>
          </div>

          <div class="flex flex-row gap-4">
            <.link navigate={@cancel_path} kind="button" variant="outline">{gettext("Cancel")}</.link>
            <.button variant="secondary">
              {if @equipment, do: gettext("Save changes"), else: gettext("Add equipment")}
            </.button>
          </div>
        </div>

        <div class="grid grid-cols-[min-content_1fr] items-start gap-x-5 gap-y-4">
          <label class="pt-1.5 text-sm text-nowrap text-grey-700" for={@form[:name].id}>
            {gettext("Name")}
          </label>
          <.input
            field={@form[:name]}
            class="max-w-90"
            placeholder={gettext("For example: MacBook Pro 14")}
          />

          <label class="pt-1.5 text-sm text-nowrap text-grey-700" for={@form[:kind].id}>
            {gettext("Kind")}
          </label>
          <.input
            type="select"
            field={@form[:kind]}
            options={@kind_options}
            container_class="max-w-90"
          />

          <label class="pt-1.5 text-sm text-nowrap text-grey-700" for={@form[:serial_number].id}>
            {gettext("Serial number")}
          </label>
          <.input field={@form[:serial_number]} class="max-w-90" />
        </div>
      </.form>
    </div>
    """
  end
end
