defmodule Firmowid.Inventory.Validations.MemberActive do
  @moduledoc "Validates that equipment is issued to a member who is not archived."
  use Ash.Resource.Validation
  use Gettext, backend: Firmowid.Gettext

  alias Firmowid.Core.Member

  require Ash.Query

  @impl true
  def validate(changeset, _opts, context) do
    case Ash.Changeset.get_attribute(changeset, :member_id) do
      # A missing or foreign member is reported by MemberInOrganization.
      nil ->
        :ok

      member_id ->
        opts = Ash.Context.to_opts(context, tenant: changeset.tenant)
        archived = Ash.Query.filter(Member, id == ^member_id and not is_nil(archived_at))

        if Ash.exists?(archived, opts) do
          {:error, field: :member_id, message: gettext_noop("is archived")}
        else
          :ok
        end
    end
  end
end
