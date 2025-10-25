--Config:
reactor = peripheral.wrap("")
outGate = peripheral.wrap("")
inGate = peripheral.wrap("")

--Script:
function reactorInfo()
  return reactor.getReactorInfo()
end
function setIn(value)
    if value<0
    then
        inGate.setFlowOverride(0)
        curIn=0
    else
        if(value>64000000)
        then
            inGate.setFlowOverride(64000000)
        else
            inGate.setFlowOverride(value)
            curIn=value
        end
    end
end
function setOut(value)
    if value<0 then
        outGate.setFlowOverride(0)
        curOut=0
    else
        outGate.setFlowOverride(value)
        curOut=value
    end
end

-- Predict
temperature = 8000
maxFuelConversion = 144 * 9 * 8
maxEnergySaturation = maxFuelConversion * 96.45061728395062 * 1000
temp50 = math.min(temperature / 200, 99)
tempRiseResist = (temp50 ^ 4) / (100 - temp50)
DERIV_CONST = -99 / (maxEnergySaturation * 10000)

prevEnergySaturation=nil
function bestEnergySaturation(info)
    local fuelConversion = info.fuelConversion
    local convLVL = fuelConversion / maxFuelConversion * 1.3 - 0.3
    local function f(E)
        local negCSat = 99 - (E / maxEnergySaturation) * 99
        local tempRiseExpo = (negCSat ^ 3) / (100 - negCSat) + 444.7
        return (tempRiseExpo - tempRiseResist * (1 - convLVL) + convLVL * 1000) / 10000
    end
    local function df(E)
        local negCSat = 99 - (E / maxEnergySaturation) * 99
        local num = negCSat^2 * (300 - 2 * negCSat)
        local den = (100 - negCSat)^2
        return DERIV_CONST * num / den
    end
    local E = prevEnergySaturation or 0
    local maxIter = 50
    for i = 1, maxIter do
        local fE = f(E)
        local dE = df(E)
        if not dE or dE == 0 or dE ~= dE or math.abs(dE) < 1e-12 then
            error("derivative breakdown")
        end
        local nextE = E - fE / dE
        if math.abs(nextE - E) < 1.0 then
            prevEnergySaturation = nextE
            return nextE
        end
        E = nextE
    end
    prevEnergySaturation = E
    return E
end

baseMaxGen=math.floor(maxEnergySaturation*0.015)

function bestOutputRate(info, bestSatRate)
  local convLVL = info.fuelConversion / maxFuelConversion * 1.3 - 0.3
  return baseMaxGen * (1 + convLVL * 2) * (1 - bestSatRate)
end

function bestInputRate(info, bestSatRate)
  return math.max(1-bestSatRate,0.01)*baseMaxGen/10.923556/0.95
end
-- Predict end

function main()
  local info = reactorInfo()
  if info.status~="running" then
    inGate.setOverrideEnabled(true)
    outGate.setOverrideEnabled(true)
    reactor.chargeReactor()
    setOut(0)
    setIn(64000000)
    while true do
      info = reactorInfo()
      if info.status=="running" then break end
      if info.temperature>=2000 and info.fieldStrength>=info.maxFieldStrength*0.49 and info.energySaturation>=info.maxEnergySaturation*0.49 then reactor.activateReactor() end
      os.sleep(0)
    end
  end
  while info.status=="running" do
    info = reactorInfo()
    if info.temperature>=8300 or info.fieldStrength<=info.maxFieldStrength*0.02 then
      setOut(0)
      setIn(64000000)
      reactor.stopReactor()
      print("Emergency stop!")
      return nil
    end
    local controllable, bestSat = pcall(bestEnergySaturation,info)
    if bestSat < 0 or bestSat > maxEnergySaturation then
      controllable = false
    end
    if not controllable then
      setOut(0)
      setIn(64000000)
      reactor.stopReactor()
      print("Emergency stop!(Uncontrollable)")
      return nil
    end
    local bestSatRate = bestSat/maxEnergySaturation
    setIn(bestInputRate(info,bestSatRate))
    setOut(bestOutputRate(info,bestSatRate))
    os.sleep(0)
  end
end

main()