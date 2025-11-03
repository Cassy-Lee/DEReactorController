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
    else
        if(value>64000000)
        then
            inGate.setFlowOverride(64000000)
        else
            inGate.setFlowOverride(value)
        end
    end
end
function setOut(value)
    if value<0 then
        outGate.setFlowOverride(0)
    else
        outGate.setFlowOverride(value)
    end
end

-- Predict
maxFuelConversion = 144*9*8
maxEnergySaturation = maxFuelConversion*96450.61728395062

u=2910897/math.sqrt(686339028913329000)
v=1/2910897^(1/3)
fuelCoe=1.3/maxFuelConversion -- convLVL=conv*fuelCoe-0.3
function cbrt(x) -- cbrt for neg/pos
    if x<0 then return -(-x)^(1/3)
    else return x^(1/3)
    end
end
function bestEnergySaturationRate(info)
    local A=info.fuelConversion*fuelCoe-0.3
    local kA=1310000*A
    local cA=6550000*A-6333295
    local utr=u*(kA-1266659)*math.sqrt(3291659-kA)
    return 1+v*(cbrt(cA+utr)+cbrt(cA-utr))
end

baseMaxGen=math.floor(maxEnergySaturation*0.015)

function bestOutputRate(info, bestSatRate)
  local convLVL=info.fuelConversion*fuelCoe-0.3
  return baseMaxGen*(1+convLVL*2)*(1-bestSatRate)
end

function bestInputRate(info, bestSatRate)
  local actualSatRate = info.energySaturation / maxEnergySaturation
  local satRate = math.min(actualSatRate,bestSatRate) -- If actually having lower sat rate and need more energy
  local normalRate = math.max(1-satRate,0.01)*baseMaxGen/10.923556/0.95
  if info.temperature > 8000 then -- If extra charge required
    local extraTemp = info.temperature-8000
    local tempCoe = 1+extraTemp*extraTemp*0.0000025
    return normalRate*tempCoe
  end
  return normalRate
end
-- Predict end

autoStopFuel = maxFuelConversion*0.8

lastSleep=nil
function sleep0()
  if not lastSleep or os.clock()>lastSleep then
    os.sleep(0)
  else
    os.sleep(0.05)
  end
  lastSleep=os.clock()
end

function main()
  local info = reactorInfo()
  if info.fuelConversion>autoStopFuel then
    print("Not enough fuel, won't start.")
    return
  end
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
      sleep0()
    end
  end
  while info.status=="running" do
    info = reactorInfo()
    if info.fuelConversion>autoStopFuel then
      print("Not enough fuel, auto stop")
      break
    end
    if info.temperature>=8100 or info.fieldStrength<=info.maxFieldStrength*0.02 then
      setOut(0)
      setIn(64000000)
      reactor.stopReactor()
      print("Emergency stop!")
      return
    end
    local bestSatRate = bestEnergySaturationRate(info)
    if not (0<bestSatRate and bestSatRate<1) then
      setOut(0)
      setIn(64000000)
      reactor.stopReactor()
      print("Emergency stop!(Uncontrollable)")
      return
    end
    setIn(bestInputRate(info,bestSatRate))
    setOut(bestOutputRate(info,bestSatRate))
    sleep0()
  end
  while info.status=="running" do
    info = reactorInfo()
    if info.temperature<=6000 then
      reactor.stopReactor()
      break
    end
    if info.temperature>=8100 or info.fieldStrength<=info.maxFieldStrength*0.02 then
      setOut(0)
      setIn(64000000)
      reactor.stopReactor()
      print("Emergency stop!")
      return
    end
    setIn(bestInputRate(info,0.99))
    setOut(bestOutputRate(info,0.99))
    sleep0()
  end
  while info.status=="stopping" do
    setIn(bestInputRate(reactorInfo(),0.99))
    sleep0()
  end
end

main()