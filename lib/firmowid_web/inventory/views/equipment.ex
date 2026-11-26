defmodule FirmowidWeb.Inventory.Views.Equipment do
  @moduledoc """
  One piece of equipment: who holds it, issuing it to an employee, taking it
  back and its whole history.
  """

  use FirmowidWeb, :live_view

  import FirmowidUI.Components.Button
  import FirmowidUI.Components.Link
  import FirmowidWeb.Inventory.Components.Equipment
  import Phoenix.Component, except: [link: 1]

  alias Firmowid.Inventory
  alias FirmowidWeb.Inventory.Components.IssueModal
  alias FirmowidWeb.Inventory.Utilities.Navigation

  on_mount {FirmowidWeb.Infrastructure.Hooks.RequireAdmin, :default}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    case Inventory.get_equipment(id, scope: socket.assigns.ash_scope, not_found_error?: false) do
      {:ok, nil} ->
        {:ok, push_navigate(socket, to: Navigation.list_path())}

      {:ok, equipment} ->
        {:ok,
         socket
         |> assign(:issuing?, false)
         |> assign(:return_form, nil)
         |> assign_equipment(equipment)}
    end
  end

  @impl true
  def handle_event("open_issue", _params, socket), do: {:noreply, assign(socket, :issuing?, true)}

  def handle_event("close_issue", _params, socket), do: {:noreply, assign(socket, :issuing?, false)}

  def handle_event("open_return", _params, socket) do
    form =
      AshPhoenix.Form.for_update(socket.assigns.equipment.current_assignment, :return,
        scope: socket.assigns.ash_scope,
        domain: Inventory,
        as: "return",
        params: %{"returned_on" => Date.to_iso8601(Date.utc_today())}
      )

    {:noreply, assign(socket, :return_form, form)}
  end

  def handle_event("close_return", _params, socket), do: {:noreply, assign(socket, :return_form, nil)}

  def handle_event("validate_return", %{"return" => params}, socket) do
    {:noreply, assign(socket, :return_form, AshPhoenix.Form.validate(socket.assigns.return_form, params))}
  end

  def handle_event("submit_return", %{"return" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.return_form, params: params) do
      {:ok, _assignment} ->
        {:noreply,
         socket
         |> assign(:return_form, nil)
         |> reload_equipment()
         |> LiveToast.put_toast(:info, gettext("The return has been recorded."))}

      {:error, form} ->
        {:noreply, assign(socket, :return_form, form)}
    end
  end

  @impl true
  def handle_info({IssueModal, :issued}, socket) do
    {:noreply,
     socket
     |> assign(:issuing?, false)
     |> reload_equipment()
     |> LiveToast.put_toast(:info, gettext("The equipment has been issued."))}
  end

  defp reload_equipment(socket) do
    assign_equipment(
      socket,
      Inventory.get_equipment!(socket.assigns.equipment.id, scope: socket.assigns.ash_scope)
    )
  end

  defp assign_equipment(socket, equipment) do
    socket
    |> assign(:equipment, equipment)
    |> assign(:page_title, equipment.name)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto flex w-full max-w-7xl flex-col gap-8 px-4 py-6 md:px-10">
      <.back navigate={Navigation.list_path()} class="justify-self-start" />

      <header class="flex flex-wrap items-start justify-between gap-4">
        <div class="space-y-1">
          <h1 class="text-3xl/[1.3] font-bold text-grey-900">{@equipment.name}</h1>
          <p class="text-sm/[1.35] text-grey-500">
            {kind_label(@equipment.kind)}
            <span :if={@equipment.serial_number}>
              · {gettext("S/N %{serial_number}", serial_number: @equipment.serial_number)}
            </span>
          </p>
        </div>
        <.link navigate={Navigation.edit_path(@equipment.id)} kind="button" variant="outline">
          {gettext("Edit")}
        </.link>
      </header>

      <.card>
        <div class="flex flex-wrap items-center justify-between gap-4">
          <div class="space-y-1">
            <p class="text-sm/[1.35] text-grey-500">{gettext("Held by")}</p>
            <.holder assignment={@equipment.current_assignment} />
            <p
              :if={@equipment.current_assignment && @equipment.current_assignment.issue_note}
              class="text-sm/[1.35] text-grey-700"
            >
              {@equipment.current_assignment.issue_note}
            </p>
          </div>
          <.button
            :if={is_nil(@equipment.current_assignment)}
            type="button"
            variant="secondary"
            phx-click="open_issue"
          >
            {gettext("Issue to an employee")}
          </.button>
          <.button
            :if={@equipment.current_assignment}
            type="button"
            variant="secondary"
            phx-click="open_return"
          >
            {gettext("Record the return")}
          </.button>
        </div>
      </.card>

      <section class="flex flex-col gap-4">
        <h2 class="text-base/tight font-medium text-grey-900">{gettext("History")}</h2>
        <p :if={@equipment.assignments == []} class="text-sm text-grey-500">
          {gettext("The equipment has not been issued yet.")}
        </p>
        <table
          :if={@equipment.assignments != []}
          id="equipment-history"
          class="w-full text-start text-sm"
        >
          <thead class="text-grey-500 max-md:hidden">
            <tr>
              <th scope="col" class="py-2 pe-4 text-start font-normal">{gettext("Employee")}</th>
              <th scope="col" class="py-2 pe-4 text-start font-normal">
                {pgettext("equipment", "Issued")}
              </th>
              <th scope="col" class="py-2 pe-4 text-start font-normal">{gettext("Returned")}</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-grey-100 bg-white">
            <tr
              :for={assignment <- @equipment.assignments}
              class="align-top max-md:flex max-md:flex-col max-md:gap-1 max-md:py-3"
            >
              <td class="px-4 py-3 text-base max-md:py-0">{assignment.member.display_name}</td>
              <td class="py-3 pe-4 max-md:px-4 max-md:py-0">
                <p class="tabular-nums">{format_date(assignment.issued_on)}</p>
                <p :if={assignment.issue_note} class="text-grey-700">{assignment.issue_note}</p>
              </td>
              <td class="py-3 pe-4 max-md:px-4 max-md:py-0">
                <p :if={assignment.returned_on} class="tabular-nums">
                  {format_date(assignment.returned_on)}
                </p>
                <p :if={assignment.return_note} class="text-grey-700">{assignment.return_note}</p>
                <.badge :if={is_nil(assignment.returned_on)}>
                  {pgettext("equipment status", "Still held")}
                </.badge>
              </td>
            </tr>
          </tbody>
        </table>
      </section>

      <.live_component
        :if={@issuing?}
        module={IssueModal}
        id="issue-equipment"
        scope={@ash_scope}
        equipment={@equipment}
        member={nil}
      />

      <.modal
        :if={@return_form}
        id="return-equipment-modal"
        show
        on_cancel={JS.push("close_return")}
        class="max-w-lg"
      >
        <:header>
          <h3 class="text-xl font-medium">{gettext("Record the return")}</h3>
          <p class="mt-1 text-sm text-grey-500">
            {gettext("%{equipment} from %{name}",
              equipment: @equipment.name,
              name: @equipment.current_assignment.member.display_name
            )}
          </p>
        </:header>
        <.form
          :let={form}
          for={to_form(@return_form)}
          id="return-equipment-form"
          phx-change="validate_return"
          phx-submit="submit_return"
          class="flex flex-col gap-6"
        >
          <.input type="date" field={form[:returned_on]} label={pgettext("equipment", "Return date")} />
          <.input
            type="textarea"
            field={form[:return_note]}
            label={gettext("Condition on return")}
            placeholder={gettext("For example: complete, scratched lid")}
          />
          <div class="flex flex-col-reverse gap-4 sm:flex-row sm:justify-end">
            <.button type="button" variant="tertiary" size="small" phx-click="close_return">
              {gettext("Cancel")}
            </.button>
            <.button type="submit" variant="secondary" size="small">
              {gettext("Record the return")}
            </.button>
          </div>
        </.form>
      </.modal>
    </div>
    """
  end
end
