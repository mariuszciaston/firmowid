defmodule Firmowid.Inventory.Validations.EquipmentAvailable do
  @moduledoc """
  Validates that the issued equipment belongs to the changeset's organization
  and nobody holds it yet.
  """
  use Ash.Resource.Validation
  use Gettext, backend: Firmowid.Gettext

  alias Firmowid.Inventory.Equipment

  require Ash.Query

  @impl true
  def validate(changeset, _opts, context) do
    case Ash.Changeset.get_attribute(changeset, :equipment_id) do
      # A missing equipment is reported by the attribute's own required check.
      nil -> :ok
      equipment_id -> validate_equipment(equipment_id, changeset, context)
    end
  end

  defp validate_equipment(equipment_id, changeset, context) do
    opts = Ash.Context.to_opts(context, tenant: changeset.tenant)
    equipment = Ash.Query.filter(Equipment, id == ^equipment_id)

    cond do
      not Ash.exists?(equipment, opts) ->
        {:error, field: :equipment_id, message: "is invalid"}

      Ash.exists?(Ash.Query.filter(equipment, exists(assignments, is_nil(returned_on))), opts) ->
        {:error, field: :equipment_id, message: gettext_noop("is already issued to someone")}

      true ->
        :ok
    end
  end
end
