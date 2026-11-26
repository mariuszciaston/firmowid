defmodule Firmowid.Seeds.Inventory do
  @moduledoc "Seeds example equipment: two pieces held by employees, one returned and one never issued."

  alias Firmowid.Inventory.Equipment
  alias Firmowid.Inventory.EquipmentAssignment
  alias Firmowid.Seeds.Helpers

  def seed!(%{users: %{sable: sable, maren: maren}, bytecraft: bytecraft}) do
    today = Helpers.today()

    macbook = seed_equipment!(bytecraft.id, "MacBook Pro 14", :laptop, "C02XY1234ABC")
    thinkpad = seed_equipment!(bytecraft.id, "Lenovo ThinkPad T14", :laptop, "PF3ABC12")
    phone = seed_equipment!(bytecraft.id, "iPhone 15", :phone, "F2LXK0001")
    seed_equipment!(bytecraft.id, "Dell U2723QE", :monitor, nil)

    seed_assignment!(bytecraft.id, macbook, sable, Date.add(today, -60), %{
      issue_note: "Z ładowarką i etui"
    })

    seed_assignment!(bytecraft.id, thinkpad, maren, Date.add(today, -30), %{
      issue_note: "Rysa na klapie"
    })

    seed_assignment!(bytecraft.id, phone, maren, Date.add(today, -120), %{
      issue_note: "Nowy, w pudełku",
      returned_on: Date.add(today, -35),
      return_note: "Kompletny, bez uszkodzeń"
    })
  end

  defp seed_equipment!(organization_id, name, kind, serial_number) do
    Ash.Seed.seed!(Equipment, %{
      organization_id: organization_id,
      name: name,
      kind: kind,
      serial_number: serial_number
    })
  end

  defp seed_assignment!(organization_id, equipment, user, issued_on, attributes) do
    Ash.Seed.seed!(
      EquipmentAssignment,
      Map.merge(
        %{
          organization_id: organization_id,
          equipment_id: equipment.id,
          member_id: user.member.id,
          issued_on: issued_on
        },
        attributes
      )
    )
  end
end
