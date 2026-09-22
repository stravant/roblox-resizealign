local TestTypes = require(script.Parent.Parent.TestTypes)
type TestContext = TestTypes.TestContext

local interpretNumberInput = require(script.Parent.interpretNumberInput)

return function(t: TestContext)
	t.test("Interprets numbers and expressions", function()
		t.expect(interpretNumberInput("12")).toBe(12)
		t.expect(interpretNumberInput(" 2 * 3 ")).toBe(6)
		t.expect(interpretNumberInput("/8")).toBe(45)
		t.expect(interpretNumberInput("nonsense")).toBe(nil)
		t.expect(interpretNumberInput("")).toBe(nil)
		t.expect(interpretNumberInput("automatic")).toBe(nil)
	end)

	t.test("Zero label in any case or empty text is zero", function()
		for _, text in { "Automatic", "automatic", " AuToMaTiC ", "", "  ", "0" } do
			t.expect(interpretNumberInput(text, "Automatic")).toBe(0)
		end
		t.expect(interpretNumberInput("12", "Automatic")).toBe(12)
		t.expect(interpretNumberInput("automati", "Automatic")).toBe(nil)
	end)
end
