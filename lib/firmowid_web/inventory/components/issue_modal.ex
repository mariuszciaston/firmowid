defmodule FirmowidWeb.Inventory.Components.IssueModal do
  @moduledoc """
  The modal that issues equipment to a member. The host fixes either the
  `equipment` or the `member` and the form picks the other one.

  The host renders it while issuing, handles the `close_issue` event of its
  cancel and receives `{IssueModal, :issued}` once the equipment is issued.
  """

  use FirmowidWeb, :live_component

  import FirmowidUI.Components.Button
  import FirmowidWeb.Inventory.Components.Equipment, only: [kind_label: 1]

  alias Firmowid.Core
  alias Firmowid.Inventory
  alias Firmowid.Inventory.EquipmentAssignment

  @impl true
  def update(assigns, socket) do
    socket = assign(socket, assigns)

    {:ok, if(socket.assigns[:form], do: socket, else: assign_form(socket))}
  end

  @impl true
  def handle_event("validate", %{"issue" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("submit", %{"issue" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _assignment} ->
        send(self(), {__MODULE__, :issued})
        {:noreply, socket}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp assign_form(socket) do
    %{scope: scope, equipment: equipment, member: member} = socket.assigns

    form =
      AshPhoenix.Form.for_create(EquipmentAssignment, :issue,
        scope: scope,
        domain: Inventory,
        as: "issue",
        params: %{
          "equipment_id" => equipment && equipment.id,
          "member_id" => member && member.id,
          "issued_on" => Date.to_iso8601(Firmowid.LocalDate.today())
        }
      )

    socket
    |> assign(:form, form)
    |> assign(:options, options(equipment, scope))
  end

  # With the equipment fixed the form picks a member, and the other way round.
  defp options(nil, scope) do
    %{status: :available}
    |> Inventory.list_equipment!(scope: scope)
    |> Enum.map(fn equipment ->
      {"#{equipment.name} (#{kind_label(equipment.kind)})", equipment.id}
    end)
  end

  defp options(_equipment, scope) do
    %{status: :active}
    |> Core.list_users!(scope: scope, load: [member: [:display_name]])
    |> Enum.map(&{&1.member.display_name, &1.member.id})
    |> Enum.sort_by(&elem(&1, 0))
  end

  @impl true
  def render(assigns) do
    form = to_form(assigns.form)
    # The fixed side is a hidden input, which shows no errors of its own.
    fixed_field = if assigns.equipment, do: form[:equipment_id], else: form[:member_id]

    assigns =
      assign(assigns,
        form: form,
        fixed_errors: Enum.map(fixed_field.errors, &FirmowidUI.Components.Inputs.translate_error/1)
      )

    ~H"""
    <div>
      <.modal id={"#{@id}-modal"} show on_cancel={JS.push("close_issue")} class="max-w-lg">
        <:header>
          <h3 class="text-xl font-medium">{gettext("Issue equipment")}</h3>
          <p class="mt-1 text-sm text-grey-500">
            {if @equipment, do: @equipment.name, else: @member.display_name}
          </p>
        </:header>

        <p :if={@options == []} class="text-sm text-grey-700">
          {if @equipment,
            do: gettext("There are no active employees to issue the equipment to."),
            else: gettext("All equipment is issued. Add equipment to the inventory first.")}
        </p>

        <.form
          :if={@options != []}
          for={@form}
          id={"#{@id}-form"}
          phx-change="validate"
          phx-submit="submit"
          phx-target={@myself}
          class="flex flex-col gap-6"
        >
          <%= if @equipment do %>
            <.input type="hidden" field={@form[:equipment_id]} />
            <.input
              type="select"
              field={@form[:member_id]}
              label={gettext("Employee")}
              prompt={gettext("Choose an employee")}
              options={@options}
            />
          <% else %>
            <.input type="hidden" field={@form[:member_id]} />
            <.input
              type="select"
              field={@form[:equipment_id]}
              label={gettext("Equipment")}
              prompt={gettext("Choose equipment")}
              options={@options}
            />
          <% end %>
          <.error :for={message <- @fixed_errors}>{message}</.error>
          <.input type="date" field={@form[:issued_on]} label={pgettext("equipment", "Issue date")} />
          <.input
            type="textarea"
            field={@form[:issue_note]}
            label={gettext("Condition on issue")}
            placeholder={gettext("For example: with a charger, no scratches")}
          />

          <div class="flex flex-col-reverse gap-4 sm:flex-row sm:justify-end">
            <.button type="button" variant="tertiary" size="small" phx-click="close_issue">
              {gettext("Cancel")}
            </.button>
            <.button type="submit" variant="secondary" size="small">
              {gettext("Issue")}
            </.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end
end
