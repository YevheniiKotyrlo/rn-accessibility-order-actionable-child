/**
 * Two identical rows: a View that is not accessible but has a label and the "activate" action (ACTION_CLICK), holding
 * two texts. The first sits in a plain container, the second in a container whose experimental_accessibilityOrder
 * names it (enableAccessibilityOrder is on, MainApplication.kt). Both rows should be nodes of the accessibility tree.
 *
 * @format
 */

import { StyleSheet, Text, View } from 'react-native';

function Row({
  label,
  nativeID,
  texts,
}: {
  readonly label: string;
  readonly nativeID: string;
  readonly texts: readonly [string, string];
}) {
  return (
    <View
      accessible={false}
      accessibilityLabel={label}
      accessibilityActions={[{ name: 'activate' }]}
      onAccessibilityAction={() => {}}
      nativeID={nativeID}
      style={styles.row}
    >
      <Text style={styles.text}>{texts[0]}</Text>
      <Text style={styles.text}>{texts[1]}</Text>
    </View>
  );
}

function App() {
  return (
    <View style={styles.screen}>
      <Text style={styles.caption}>
        Both rows offer the activate action. The second sits in a container
        whose accessibility order names it.
      </Text>
      <View style={styles.container}>
        <Row
          label="row without order"
          nativeID="row-without-order"
          texts={['first text', 'second text']}
        />
      </View>
      <View
        experimental_accessibilityOrder={['row-in-order']}
        style={styles.container}
      >
        <Row
          label="row in order"
          nativeID="row-in-order"
          texts={['third text', 'fourth text']}
        />
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: {
    flex: 1,
    backgroundColor: 'white',
    paddingHorizontal: 24,
    paddingTop: 64,
    gap: 16,
  },
  caption: {
    color: 'black',
    fontSize: 16,
  },
  container: {
    borderColor: '#999999',
    borderWidth: 1,
    padding: 8,
  },
  row: {
    backgroundColor: '#eeeeee',
    gap: 4,
    padding: 12,
  },
  text: {
    color: 'black',
    fontSize: 16,
  },
});

export default App;
