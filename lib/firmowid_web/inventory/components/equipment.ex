defmodule FirmowidWeb.Inventory.Components.Equipment do
  @moduledoc "Presentation of equipment shared by the inventory, the employee profile and the member's settings."

  use FirmowidWeb, :html

  import FirmowidUI.Components.Link
  import Phoenix.Component, except: [link: 1]

  alias FirmowidWeb.Inventory.Utilities.Navigation
  alias Phoenix.LiveView.Rendered

  @doc "The name of an equipment kind."
  @spec kind_label(atom()) :: String.t()
  def kind_label(:laptop), do: pgettext("equipment kind", "Laptop")
  def kind_label(:phone), do: pgettext("equipment kind", "Phone")
  def kind_label(:monitor), do: pgettext("equipment kind", "Monitor")
  def kind_label(:other), do: pgettext("equipment kind", "Other")

  @doc "Formats a date of the inventory, such as 12.03.2026."
  @spec format_date(Date.t() | nil) :: String.t() | nil
  def format_date(nil), do: nil
  def format_date(date), do: Calendar.strftime(date, "%d.%m.%Y")

  @doc "Renders who holds the equipment and since when, or that it is available."
  @spec holder(map()) :: Rendered.t()
  attr :assignment, :any, required: true, doc: "the open assignment with its member, or nil"

  def holder(%{assignment: nil} = assigns) do
    ~H"""
    <.badge tone="success">{pgettext("equipment status", "Available")}</.badge>
    """
  end

  def holder(assigns) do
    ~H"""
    <span class="text-sm/[1.35] text-grey-900">
      {gettext("%{name}, since %{date}",
        name: @assignment.member.display_name,
        date: format_date(@assignment.issued_on)
      )}
    </span>
    """
  end

  @doc """
  Renders the equipment a member holds: its open assignments with the equipment
  loaded. With `link?` each one opens its page in the inventory.
  """
  @spec held_equipment(map()) :: Rendered.t()
  attr :assignments, :list, required: true
  attr :link?, :boolean, default: false
  attr :empty_text, :string, required: true

  def held_equipment(assigns) do
    ~H"""
    <ul :if={@assignments != []} class="divide-y divide-grey-100">
      <li :for={assignment <- @assignments} class="flex items-start gap-4 py-3 first:pt-0 last:pb-0">
        <div class="min-w-0 flex-1">
          <.link
            :if={@link?}
            kind="unstyled"
            navigate={Navigation.equipment_path(assignment.equipment.id)}
            class="block truncate text-base hover:underline"
          >
            {assignment.equipment.name}
          </.link>
          <p :if={!@link?} class="truncate text-base">{assignment.equipment.name}</p>
          <p class="text-sm/[1.35] text-grey-500">
            {kind_label(assignment.equipment.kind)}
            <span :if={assignment.equipment.serial_number}>
              · {gettext("S/N %{serial_number}", serial_number: assignment.equipment.serial_number)}
            </span>
          </p>
          <p :if={assignment.issue_note} class="mt-1 text-sm/[1.35] text-grey-700">
            {assignment.issue_note}
          </p>
        </div>
        <p class="shrink-0 text-sm/[1.35] text-grey-700 tabular-nums">
          {gettext("since %{date}", date: format_date(assignment.issued_on))}
        </p>
      </li>
    </ul>
    <p :if={@assignments == []} class="text-sm text-grey-500">{@empty_text}</p>
    """
  end
end
